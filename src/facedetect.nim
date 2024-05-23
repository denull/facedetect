import std/[streams, algorithm, tables, random, os, math, strformat]
import facedetect/private/streamutils
import pixie

type
  Image8* = object
    ## Image8 is a container for 8-bit grayscale image.
    ## width: the number of image rows.
    ## height: the number of image columns.
    ## data: contains the grayscale converted image pixel data.
    width*, height*: int
    data*: seq[uint8]

  FaceCascade* = object
    ## Defines the basic binary tree components for face data.
    codes: seq[int8]
    preds: seq[float32]
    thresholds: seq[float32]
    treeDepth: uint32
    treeNum: uint32

  LandmarkCascade* = object
    ## Defines the basic binary tree components for landmark data.
    codes: seq[int8]
    preds: seq[float32]
    treeDepth: uint32
    treeNum: uint32
    scales: float32
    stages: uint32

  Face* = object
    ## Face contains the detection results composed of
    ## the row, column, scale factor and the detection score.
    x*, y*: float32
    scale*: float32
    score*: float32

  Landmark* = object
    ## Landmark contains all the information resulted from the pupil detection
    ## needed for accessing from a global scope.
    x*, y*: float32
    scale*: float32

  FaceDetector* = object
    ## FaceDetector is a high-level API for detecting faces, eyes and optionally other landmarks
    faceCascade*: FaceCascade # Face cascade
    eyesCascade*: LandmarkCascade # Eye cascade
    landmarkCascades*: Table[string, LandmarkCascade] # Landmark cascades

  Person* = object
    ## Person contains information about face, eyes and other landmarks positions
    face*: Face
    eyes*: array[0..1, ref Landmark]
    landmarks*: Table[string, Landmark]

  Cascades* = object
    facefinder*: string
    puploc*: string
    lps*: Table[string, string]

const qCosTable = [256, 251, 236, 212, 181, 142, 97, 49, 0, -49, -97, -142, -181, -212, -236, -251, -256, -251, -236, -212, -181, -142, -97, -49, 0, 49, 97, 142, 181, 212, 236, 251, 256]
const qSinTable = [0, 49, 97, 142, 181, 212, 236, 251, 256, 251, 236, 212, 181, 142, 97, 49, 0, -49, -97, -142, -181, -212, -236, -251, -256, -251, -236, -212, -181, -142, -97, -49, 0]

const eyeCascades* = ["lp46", "lp44", "lp42", "lp38", "lp312"]
const mouthCascades* = ["lp93", "lp84", "lp82", "lp81"]

# weird conversion from 8 to 16 bit color component; but that's how color works in Go implementation
proc comp(c: uint8): float64 {.inline.} = float64((int(c) shl 8) or int(c))

# Luminosity func from chroma
proc lum(pixel: ColorRGBX): float64 {.inline.} =
  (0.299 * comp(pixel.r) + 0.587 * comp(pixel.g) + 0.114 * comp(pixel.b)) / 256.0

proc grayscale*(image: pixie.Image): Image8 =
  result = Image8(width: image.width, height: image.height, data: newSeq[uint8](image.width * image.height))
  for i, pixel in image.data:
    result.data[i] = uint8(clamp(lum(pixel), 0.0..255.0))

proc readGrayscaleImage*(filePath: string): Image8 =
  readImage(filePath).grayscale

proc readFaceCascade*(fs: Stream): FaceCascade =
  ## Unpack the binary face classification file.
  fs.setPosition(8)
  result.treeDepth = fs.readUint32le()
  result.treeNum = fs.readUint32le()
  result.thresholds = newSeqOfCap[float32](int(result.treeNum))
  result.codes = newSeqOfCap[int8](119808)
  result.preds = newSeqOfCap[float32](29952)
  let treeSize = 1 shl result.treeDepth
  for t in 0..<result.treeNum:
    let i = result.codes.len + 4
    result.codes.setLen(result.codes.len + treeSize * 4)
    discard fs.readData(addr result.codes[i], treeSize * 4 - 4)
    for i in 0..<treeSize:
      result.preds.add(fs.readFloat32le())
    result.thresholds.add(fs.readFloat32le())

proc readFaceCascade*(filename: string = "cascade/facefinder"): FaceCascade =
  ## Unpack the binary face classification file.
  readFaceCascade(openFileStream(filename))

proc readLandmarkCascade*(fs: Stream): LandmarkCascade =
  ## Unpacks the pupil localization cascade file
  result.codes = newSeqOfCap[int8](409200)
  result.preds = newSeqOfCap[float32](204800)
  result.stages = fs.readUint32le()
  result.scales = fs.readFloat32le()
  result.treeNum = fs.readUint32le()
  result.treeDepth = fs.readUint32le()
  for s in 0..<result.stages:
    for t in 0..<result.treeNum:
      let size = 1 shl result.treeDepth
      let idx = result.codes.len
      result.codes.setLen(idx + size * 4 - 4)
      discard fs.readData(addr result.codes[idx], size * 4 - 4)
      for i in 0..<size:
        for l in 0..<2:
          result.preds.add(fs.readFloat32le())

proc readLandmarkCascade*(filename: string = "cascade/puploc"): LandmarkCascade =
  ## Unpacks the pupil localization cascade file
  readLandmarkCascade(openFileStream(filename))

proc readLandmarkCascadeDir*(dir: string = "cascade/lps"): Table[string, LandmarkCascade] =
  ## Reads the facial landmark points cascade files from the provided directory.
  for kind, path in walkDir(dir):
    if kind == pcFile:
      result[extractFilename(path)] = readLandmarkCascade(path)

proc readLandmarkCascadeDir(lps: Table[string, string]): Table[string, LandmarkCascade] =
  for name, blob in lps:
    result[name] = readLandmarkCascade(newStringStream(blob))

{.push checks: off.} # Those functions take most of CPU time, so we disable range/overflow checks temporarily
proc classifyRegion(fc: FaceCascade, x, y, s, treeSize: int, data: seq[uint8], w: int): float32 =
  ## Constructs the classification function based on the parsed binary data
  var root: int
  let x = x * 256
  let y = y * 256
  var offs: int
  if fc.treeNum <= 0:
    return 0.0
  for i in 0..<fc.treeNum:
    var idx = 1
    for j in 0..<fc.treeDepth:
      offs = root + (idx shl 2)
      let i1 =
        ((y + int(fc.codes[offs + 0]) * s) shr 8) * w +
        ((x + int(fc.codes[offs + 1]) * s) shr 8)
      let i2 =
        ((y + int(fc.codes[offs + 2]) * s) shr 8) * w +
        ((x + int(fc.codes[offs + 3]) * s) shr 8)
      #print i, j, i1, i2
      #print data[i1], data[i2]
      idx = (idx shl 1) or int(data[i1] <= data[i2])
    result += fc.preds[treeSize * (int(i) - 1) + idx]
    if result <= fc.thresholds[i]:
      return -1.0
    root += 4 * treeSize
  return result - fc.thresholds[fc.treeNum - 1]

proc classifyRotatedRegion(fc: FaceCascade, x, y, s, treeSize: int, a: float64, data: seq[uint8], w, h: int): float32 =
  ## Applies the face classification function over a rotated image based on the parsed binary data.
  var root: int
  let qsin = s * qSinTable[int(32.0 * a)]
  let qcos = s * qCosTable[int(32.0 * a)]
  if fc.treeNum <= 0:
    return 0.0
  for i in 0..<fc.treeNum:
    var idx = 1
    for j in 0..<fc.treeDepth:
      let y1 = abs(min(h - 1, max(0, (y shl 16) + qcos * int(fc.codes[root + 4 * idx + 0]) - qsin * int(fc.codes[root + 4 * idx + 1])) shr 16))
      let x1 = abs(min(w - 1, max(0, (x shl 16) + qsin * int(fc.codes[root + 4 * idx + 0]) + qcos * int(fc.codes[root + 4 * idx + 1])) shr 16))

      let y2 = abs(min(h - 1, max(0, (y shl 16) + qcos * int(fc.codes[root + 4 * idx + 2]) - qsin * int(fc.codes[root + 4 * idx + 3])) shr 16))
      let x2 = abs(min(w - 1, max(0, (x shl 16) + qsin * int(fc.codes[root + 4 * idx + 2]) + qcos * int(fc.codes[root + 4 * idx + 3])) shr 16))

      idx = (idx shl 1) or int(data[y1 * w + x1] <= data[y2 * w + x2])
    result += fc.preds[treeSize * (int(i) - 1) + idx]

    if result <= fc.thresholds[i]:
      return -1.0
    root += 4 * treeSize
  return result - fc.thresholds[fc.treeNum - 1]

proc classifyRegion(lc: LandmarkCascade, x, y, s: float32, treeSize: int, data: seq[uint8], w, h: int, flipV: bool): tuple[x, y, s: float32] =
  ## Applies the landmark classification function over an image (starting from the approximate position).
  # flipV means that we wish to flip the column coordinates sign in the tree nodes.
  # This is required at running the facial landmark detector over the right side of the detected face.
  let m = (if flipV: -1 else: 1)
  var (x, y, s) = (x, y, s)
  var root = 0
  for i in 0..<int(lc.stages):
    var dx, dy = 0.0
    let (sx, sy) = (int(x) shl 8, int(y) shl 8)
    for j in 0..<int(lc.treeNum):
      var idx = 0
      for k in 0..<lc.treeDepth:
        let x1 = min(w - 1, max(0, (sx + m * int(float(lc.codes[root + 4 * idx + 1]) * s)) shr 8))
        let x2 = min(w - 1, max(0, (sx + m * int(float(lc.codes[root + 4 * idx + 3]) * s)) shr 8))
        let y1 = min(h - 1, max(0, (sy + int(float(lc.codes[root + 4 * idx + 0]) * s)) shr 8))
        let y2 = min(h - 1, max(0, (sy + int(float(lc.codes[root + 4 * idx + 2]) * s)) shr 8))
        idx = 2 * idx + 1 + int(data[y1 * w + x1] > data[y2 * w + x2])
      let lutIdx = 2 * (int(lc.treeNum) * treeSize * i + treeSize * j + idx - (treeSize - 1))
      dx += float(m) * lc.preds[lutIdx + 1]
      dy += lc.preds[lutIdx + 0]
      root += 4 * treeSize - 4
    x += dx * s
    y += dy * s
    s *= lc.scales
  return (x, y, s)

proc classifyRotatedRegion(lc: LandmarkCascade, x, y, s: float32, treeSize: int, a: float64, data: seq[uint8], w, h: int, flipV: bool): tuple[x, y, s: float32] =
  ## Applies the landmark classification function over a rotated image (starting from the approximate position).
  # flipV means that we wish to flip the column coordinates sign in the tree nodes.
  # This is required at running the facial landmark detector over the right side of the detected face.
  let m = (if flipV: -1 else: 1)
  var (x, y, s) = (x, y, s)
  let qsin = int(s * float(qSinTable[int(32.0 * a)])) # TODO: shouldn't qsin/qcos be recomputed when s is updated (at the end of the loop)?
  let qcos = int(s * float(qCosTable[int(32.0 * a)]))
  var root = 0
  for i in 0..<int(lc.stages):
    var dx, dy = 0.0
    let (sx, sy) = (int(x) shl 16, int(y) shl 16)
    for j in 0..<int(lc.treeNum):
      var idx = 0
      for k in 0..<lc.treeDepth:
        let cx1 = m * int(lc.codes[root + 4 * idx + 1])
        let cx2 = m * int(lc.codes[root + 4 * idx + 3])
        let cy1 = int(lc.codes[root + 4 * idx + 0])
        let cy2 = int(lc.codes[root + 4 * idx + 2])
        let x1 = max(0, min(w - 1, (sx + qsin * cy1 + qcos * cx1) shr 16))
        let y1 = max(0, min(h - 1, (sy + qcos * cy1 - qsin * cx1) shr 16))
        let x2 = max(0, min(w - 1, (sx + qsin * cy2 + qcos * cx2) shr 16))
        let y2 = max(0, min(h - 1, (sy + qcos * cy2 - qsin * cx2) shr 16))
        idx = 2 * idx + 1 + int(data[y1 * w + x1] > data[y2 * w + x2])
      let lutIdx = 2 * (int(lc.treeNum) * treeSize * i + treeSize * j + idx - (treeSize - 1))
      dx += float(m) * lc.preds[lutIdx + 1]
      dy += lc.preds[lutIdx + 0]
      root += 4 * treeSize - 4
    x += dx * s
    y += dy * s
    s *= lc.scales
  return (x, y, s)
{.pop.}

proc cluster*(faces: seq[Face], iouThreshold: float64): seq[Face] =
  ## Returns the intersection over union of multiple clusters.
  ## We need to make this comparison to filter out multiple face detection regions.
  var faces = faces
  sort(faces) do (f1, f2: Face) -> int:
    cmp(f1.score, f2.score)

  var assignments = newSeq[bool](faces.len)
  for i, face1 in faces:
    # Compare the intersection over union only for two different clusters.
    # Skip the comparison in case there already exists a cluster A in the bucket.
    if assignments[i]:
      continue
    var x, y, s, q, n: float32
    for j, face2 in faces:
      # Check if the comparison result is above a certain threshold.
      # In this case we union the detections.
      let (x1, y1, s1) = (float64(face1.x), float64(face1.y), float64(face1.scale))
      let (x2, y2, s2) = (float64(face2.x), float64(face2.y), float64(face2.scale))

      let x0 = max(0, min(x1 + s1 / 2, x2 + s2 / 2) - max(x1 - s1 / 2, x2 - s2 / 2))
      let y0 = max(0, min(y1 + s1 / 2, y2 + s2 / 2) - max(y1 - s1 / 2, y2 - s2 / 2))
      let iou = x0 * y0 / (s1 * s1 + s2 * s2 - x0 * y0)

      if iou > iouThreshold:
        assignments[j] = true
        x += face2.x
        y += face2.y
        s += face2.scale
        q += face2.score
        n += 1
    if n > 0:
      result.add(Face(x: x / n, y: y / n, scale: s / n, score: q))

proc detect*(fc: FaceCascade, image: Image8, minSize: int = 100, maxSize: int = 600, shiftFactor: float64 = 0.15, scaleFactor: float64 = 1.1, angle = 0.0, iouThreshold = 0.1): seq[Face] =
  ## Analyze the grayscale converted image pixel data and run the classification function over the detection window.
  ## It will return a slice containing the detection row, column, it's center and the detection score (in case this is greater than 0.0).
  var data = image.data
  let treeSize = 1 shl fc.treeDepth
  var scale = minSize
  var q: float32

  # Run the classification function over the detection window
  # and check if the false positive rate is above a certain value.
  while scale <= maxSize:
    let step = int(max(shiftFactor * float64(scale), 1.0))
    let offset = scale shr 1 + 1

    for y in countup(offset, image.height - offset, step):
      for x in countup(offset, image.width - offset, step):
        if angle > 0.0:
          q = fc.classifyRotatedRegion(x, y, scale, treeSize, min(angle, 1.0), data, image.height, image.width)
        else:
          q = fc.classifyRegion(x, y, scale, treeSize, data, image.width)

        if q > 0.0:
          result.add(Face(x: float32(x), y: float32(y), scale: float32(scale), score: q))

    # We need to avoid running into an infinite loop because of float to int conversion
    # in cases when scaleFactor == 1.1 and minSize == 9 as example.
    # When the scale is 9, the factor would come up with 9.9, which again becomes 9 because of the int() conversion.
    # This approach gives the same speed without having an impact on the detection score.
    scale = int(float64(scale) + max(2.0, float64(scale) * scaleFactor - float64(scale)))

  if iouThreshold >= 0.0:
    result = result.cluster(iouThreshold)

proc detect*(lc: LandmarkCascade, image: Image8, x, y, scale: float32, perturbs: int, angle: float64 = 0.0, flipV: bool = false): Landmark =
  ## Runs the pupil/landmark localization function.
  var res: tuple[x, y, s: float32]
  let treeSize = 1 shl int(lc.treeDepth)
  var xs, ys, ss: array[0..62, float32]
  for i in 0..<perturbs:
    let x1 = float32(x) + scale * 0.15 * rand(-0.5..0.5)
    let y1 = float32(y) + scale * 0.15 * rand(-0.5..0.5)
    let sc = scale * (0.925 + 0.15 * rand(0.0..1.0))
    if angle > 0.0:
      res = lc.classifyRotatedRegion(x1, y1, sc, treeSize, min(1.0, angle), image.data, image.width, image.height, flipV)
    else:
      res = lc.classifyRegion(x, y, sc, treeSize, image.data, image.width, image.height, flipV)
    xs[i] = res.x
    ys[i] = res.y
    ss[i] = res.s
  # Sorting the perturbations in ascending order
  sort(xs)
  sort(ys)
  sort(ss)
  let mid = int(round(float(perturbs) / 2.0))
  return Landmark(x: xs[mid], y: ys[mid], scale: ss[mid])

proc detect*(lc: LandmarkCascade, leftEye, rightEye: Landmark, image: Image8, perturbs: int, flipV: bool): Landmark =
  ## Retrieves the facial landmark point based on the pupil localization results.
  let dx = leftEye.x - rightEye.x
  let dy = leftEye.y - rightEye.y
  let dist = sqrt(float64(dx * dx + dy * dy))
  let x = float(leftEye.x + rightEye.x) / 2.0 + 0.15 * dist # maybe -0.15 if flipV?
  let y = float(leftEye.y + rightEye.y) / 2.0 + 0.25 * dist
  lc.detect(image, x, y, 3.0 * dist, perturbs, 0.0, flipV)

# Some code based on photoprism
# Using values from https://github.com/photoprism/photoprism/blob/develop/internal/face/thresholds.go

const overlapThreshold = 0.42                      # Face area overlap threshold in percent.
const overlapThresholdFloor = overlapThreshold - 0.01 # Reduced overlap area to avoid rounding inconsistencies.
const scoreThreshold = 9.0                       # Min face score.

#[
const clusterScoreThreshold = 15                 # Min score for faces forming a cluster.
const sizeThreshold = 50                         # Min face size in pixels.
const clusterSizeThreshold = 80                  # Min size for faces forming a cluster in pixels.
const clusterDist = 0.64                         # Similarity distance threshold of faces forming a cluster core.
const matchDist = 0.46                           # Dist offset threshold for matching new faces with clusters.
const clusterCore = 4                            # Min number of faces forming a cluster core.
const sampleThreshold = 2 * clusterCore          # Threshold for automatic clustering to start.
]#

proc qualityThresholdFunc*(scale: float32): float32 =
  ## Returns the scale adjusted quality score threshold.
  result = scoreThreshold

  # Smaller faces require higher quality.
  if scale < 26:
    result += 26.0
  elif scale < 32:
    result += 16.0
  elif scale < 40:
    result += 11.0
  elif scale < 50:
    result += 9.0
  elif scale < 80:
    result += 6.0
  elif scale < 110:
    result += 2.0

proc initFaceDetector*(cascadeDir: string = "cascade"): FaceDetector =
  result.faceCascade = readFaceCascade(joinPath(cascadeDir, "facefinder"))
  result.eyesCascade = readLandmarkCascade(joinPath(cascadeDir, "puploc"))
  result.landmarkCascades = readLandmarkCascadeDir(joinPath(cascadeDir, "lps"))

proc initFaceDetector*(cascades: Cascades): FaceDetector =
  result.faceCascade = readFaceCascade(newStringStream(cascades.facefinder))
  result.eyesCascade = readLandmarkCascade(newStringStream(cascades.puploc))
  result.landmarkCascades = readLandmarkCascadeDir(cascades.lps)

proc overlap(face1, face2: Face): float64 =
  let s1 = face1.scale / 2
  let s2 = face2.scale / 2
  let x = max(0, min(face1.x + s1, face2.x + s2) - max(face1.x - s1, face2.x - s2))
  let y = max(0, min(face1.y + s1, face2.y + s2) - max(face1.y - s1, face2.y - s2))
  let area = x * y
  if area <= 0:
    return 0.0
  let s = face2.scale * face2.scale
  if s <= 0:
    return 0.0
  if area > s:
    return s / area
  return area / s

proc contains(people: seq[Person], p: Person, threshold: float32): bool =
  for person in people:
    if person.face.overlap(p.face) * 100.0 > float(threshold):
      return true

proc detect*(fd: FaceDetector, image: Image8,
  findLandmarks: bool = true,
  minSize: int = 20,
  maxSize: int = 1000,
  minLandmarksScale: float32 = 50,
  shiftFactor: float32 = 0.1,
  scaleFactor: float32 = 1.1,
  perturbs: int = 63,
  angle: float32 = 0.0,
  overlapThreshold: float32 = overlapThresholdFloor,
  qualityThreshold: proc(scale: float32): float32 = qualityThresholdFunc,
): seq[Person] =
  let minSize = max(minSize, 20)
  if image.width < minSize or image.height < minSize:
    raise newException(ValueError, fmt"Image size {image.width}x{image.height} is too small.")
  let maxSize = min(maxSize, min(image.width, image.height) - 4)

  # Detect
  var faces = fd.faceCascade.detect(image, minSize, maxSize, shiftFactor, scaleFactor, angle, overlapThreshold)

  # Faces
  # Sort results by size
  sort(faces) do (f1, f2: Face) -> int:
    -cmp(f1.scale, f2.scale)

  for face in faces:
    if face.score < qualityThreshold(face.scale):
      continue

    var person = Person(face: face)

    # Detect additional face landmarks?
    if findLandmarks and face.scale > minLandmarksScale:
      # Find left eye
      let xl = float(face.x) - 0.185 * float32(face.scale) # for some reason photoprism and bububa/facenet use 0.175 (but only for left eye); 0.185 is from pigo examples
      let xr = float(face.x) + 0.185 * float32(face.scale)
      let y = float(face.y) - 0.075 * float32(face.scale) # pigo uses 0.4 here
      let scale = float32(face.scale) * 0.25

      let leftEye = fd.eyesCascade.detect(image, xl, y, scale, perturbs, angle, false)
      if leftEye.x > 0 and leftEye.y > 0:
        person.eyes[0] = new Landmark
        person.eyes[0][] = leftEye

      # Find right eye
      let rightEye = fd.eyesCascade.detect(image, xr, y, scale, perturbs, angle, false) # shouldn't be right eye be flipped for better detection?
      if rightEye.x > 0 and rightEye.y > 0:
        person.eyes[1] = new Landmark
        person.eyes[1][] = rightEye

      if not isNil(person.eyes[0]) and not isNil(person.eyes[1]):
        for name in eyeCascades:
          if name notin fd.landmarkCascades:
            continue
          let flpc = fd.landmarkCascades[name]
          for flip in false..true:
            let flp = flpc.detect(leftEye, rightEye, image, perturbs, flip)
            if flp.x > 0 and flp.y > 0:
              person.landmarks[name & (if flip: "" else: "_v")] = flp

      # Find mouth
      for name in mouthCascades:
        if name notin fd.landmarkCascades:
          continue
        let flpc = fd.landmarkCascades[name]
        let flp = flpc.detect(leftEye, rightEye, image, perturbs, false)
        if flp.x > 0 and flp.y > 0:
          person.landmarks[name] = flp

      if "lp84" in fd.landmarkCascades:
        let flpc = fd.landmarkCascades["lp84"]
        let flp = flpc.detect(leftEye, rightEye, image, perturbs, true)
        if flp.x > 0 and flp.y > 0:
          person.landmarks["lp84_v"] = flp

    if not result.contains(person, overlapThreshold):
      result.add(person)