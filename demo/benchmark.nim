import std/monotimes, stats, times
import pixie
import ../src/facedetect

let fc = readFaceCascade()
let image = readImage("tests/testdata/sample.jpg")

proc benchFun(): int =
  let grayscale = image.grayscale()
  let faces = fc.detect(grayscale, minSize = 20, maxSize = 1000, shiftFactor = 0.2, scaleFactor = 1.1, iouThreshold = 0.1)
  return faces.len

when true:
  var r: RunningStat
  for iterations in 1..10:
    let start = getMonoTime()
    var sum = 0
    let reps = 30
    for i in 0 ..< reps:
      sum += benchFun()
    r.push float((getMonoTime() - start).inMilliseconds) / float(reps)
    echo int(float(sum) / float(reps))
  echo r

# BenchmarkGoCV-12              10         106933090 ns/op (106ms)
# BenchmarkPIGO-12              14          81145464 ns/op (81ms)
#
# facedetect (no flags; debug build):               195ms
# facedetect (-d:release):                          55ms
# facedetect (-d:danger):                           55ms
# facedetect (-d:danger --passC:"-O3 -flto -m64"):  54ms