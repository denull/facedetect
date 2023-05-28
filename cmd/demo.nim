import ../src/facedetect
import strformat, strutils, os, times, tables
import pixie

import wNim/[wApp, wDataObject, wAcceleratorTable, 
  wFrame, wPanel, wMenuBar, wMenu, wIcon, wImage, wBitmap,
  wStatusBar, wStaticText, wTextCtrl, wListBox, wStaticBitmap, wMemoryDC, wStaticBox, wPaintDC, wBrush, wPen, wCheckBox, wSlider, wButton, wFileDialog]

type
  MenuID = enum
    idImage = wIdUser, idExit

let app = App(wSystemDpiAware)
var data = DataObject("")

let frame = Frame(title="Face Detection Demo", size=(2000, 1200),
  style=wDefaultFrameStyle or wDoubleBuffered)

let statusBar = StatusBar(frame)
let menuBar = MenuBar(frame)
let panel = Panel(frame)
panel.setDropTarget()

let menu = Menu(menuBar, "&File")
menu.append(idImage, "Load Image", "Loads image.")
menu.appendSeparator()
menu.append(idExit, "E&xit", "Exit the program.")

let label = StaticText(panel, label="Image:")

let settings = StaticBox(panel, label="Settings")
let cbFindLandmarks = CheckBox(settings, label="Find eyes and other landmarks")
let lbMinSize = StaticText(settings, label="Min size: 20")
let slMinSize = Slider(settings, value=20, range=5..1000)
let lbMaxSize = StaticText(settings, label="Max size: 1000")
let slMaxSize = Slider(settings, value=1000, range=5..1000)
let lbMinLandmarksScale = StaticText(settings, label="Min landmarks scale: 50")
let slMinLandmarksScale = Slider(settings, value=50, range=5..1000)
let lbShiftFactor = StaticText(settings, label="Shift factor: 0.1")
let slShiftFactor = Slider(settings, value=100, range=1..1000)
let lbScaleFactor = StaticText(settings, label="Scale factor: 1.1")
let slScaleFactor = Slider(settings, value=110, range=1..1000)
let lbPerturbs = StaticText(settings, label="Perturbs: 63")
let slPerturbs = Slider(settings, value=63, range=0..63)
let lbAngle = StaticText(settings, label="Angle: 0.0deg")
let slAngle = Slider(settings, value=0, range= -1800..1800)
let lbOverlapThreshold = StaticText(settings, label="Overlap threshold: 0.41")
let slOverlapThreshold = Slider(settings, value=410, range=0..1000)
let cbAutoUpdate = CheckBox(settings, label="Auto update")
let btnUpdate = Button(settings, label="Update")

cbFindLandmarks.setValue(true)
cbAutoUpdate.setValue(true)
slMaxSize.setValue(1000)
slScaleFactor.setValue(110)
slOverlapThreshold.setValue(410)

let list = ListBox(panel, style=wLbSingle or wLbNeededScroll)
let imagePanel = Panel(panel)
var currentBitmap: wBitmap
var grayImage: Image8
var currentPeople: seq[Person] = @[]
var currentFaces: seq[Face] = @[]
var loadStatus: string

#let fc = readFaceCascade()
let detector = initFaceDetector()

var files = newSeq[string]()
for fname in walkDirRec("tests/testdata", relative=true):
  let parts = split(fname, '/')
  list.append(parts[^1])
  files &= "tests/testdata/" & fname

imagePanel.wEvent_Paint do (event: wEvent):
  if isNil(currentBitmap):
    return
  let size = event.window.clientSize
  let k = min(size.width / currentBitmap.width, size.height / currentBitmap.height)

  var dc = PaintDC(event.window)
  dc.brush = wTransparentBrush
  dc.scale = (k, k)

  var x0 = (float(size.width) / k - float(currentBitmap.width)) / 2
  var y0 = (float(size.height) / k - float(currentBitmap.height)) / 2

  dc.drawBitmap(currentBitmap, int(x0), int(y0))
  for face in currentFaces:
    dc.pen = Pen(color=0xFF3030, width=3)
    dc.drawRoundedRectangle(int(x0 + face.x - (face.scale / 2)), int(y0 + face.y - (face.scale / 2)), int(face.scale), int(face.scale), 5)

  for person in currentPeople:
    let face = person.face
    dc.pen = Pen(color=0xFF3030, width=3)
    dc.drawRoundedRectangle(int(x0 + face.x - (face.scale / 2)), int(y0 + face.y - (face.scale / 2)), int(face.scale), int(face.scale), 5)
    for eye in person.eyes:
      if isNil(eye):
        continue
      dc.pen = Pen(color=0x3030FF, width=3)
      dc.drawRoundedRectangle(int(x0 + eye.x - (eye.scale / 2)), int(y0 + eye.y - (eye.scale / 2)), int(eye.scale), int(eye.scale), 5)
    for name, landmark in person.landmarks:
      dc.pen = Pen(color=0x30FFFF, width=3)
      let sz = 1
      dc.drawRoundedRectangle(int(x0 + landmark.x) - sz, int(y0 + landmark.y) - sz, sz * 2, sz * 2, 5)

proc num(n: int, opts: varargs[string]): string =
  if n == 1:
    return opts[0]
  return opts[1]

proc update(force: bool = false) =
  if grayImage.width == 0 or grayImage.height == 0:
    return
  if not force and not cbAutoUpdate.isChecked:
    return

  let st = epochTime()
  #currentFaces = fc.detect(grayImage)
  #currentFaces = fc.detect(grayImage, minSize = 20, shiftFactor = 0.1, scaleFactor = 1.1, iouThreshold = 0.41)
  #currentFaces = detector.faceCascade.detect(grayImage, minSize = 20, maxSize = 1000, shiftFactor = 0.2, scaleFactor = 1.1, iouThreshold = 0.1)
  #echo currentFaces
  currentPeople = detector.detect(grayImage,
    findLandmarks = cbFindLandmarks.isChecked,
    minSize = slMinSize.value,
    maxSize = slMaxSize.value,
    minLandmarksScale = float(slMinLandmarksScale.value),
    shiftFactor = float(slShiftFactor.value) / 1000,
    scaleFactor = float(slScaleFactor.value) / 100,
    perturbs = slPerturbs.value,
    angle = float(slAngle.value) / 10,
    overlapThreshold = float(slOverlapThreshold.value) / 1000
  )
  let s = num(currentPeople.len, "", "s")
  let detectStatus = fmt"{currentPeople.len} face{s} detected in {epochTime() - st:.3f}s"
  echo detectStatus

  statusBar.setStatusText(fmt"{loadStatus}; {detectStatus}")
  imagePanel.refresh(true)

proc loadImage(fname: string) =
  echo fmt"Loading file {fname}"
  currentBitmap = Bitmap(Image(fname))

  var st = epochTime()
  grayImage = readGrayscaleImage(fname)
  loadStatus = fmt"{currentBitmap.width}x{currentBitmap.height} ({float(currentBitmap.width*currentBitmap.height) / 1000000.0:.2f} MP) image loaded in {epochTime() - st:.3f}s"
  echo loadStatus

  update(true)
  

proc layout() =
  panel.autolayout """
    spacing: 15
    H:|-[label,list(500)]-[imagePanel]-|
    H:|-[settings]-|
    V:|-[label][list]-[settings(390)]-|
    V:|-[imagePanel]-[settings(390)]-|
  """

  settings.autolayout """
    H:|-[lbMinSize,slMinSize,lbMaxSize,slMaxSize,lbMinLandmarksScale,slMinLandmarksScale(==33%)]-[lbShiftFactor,slShiftFactor,lbScaleFactor,slScaleFactor,lbPerturbs,slPerturbs(==33%)]-[lbAngle,slAngle,lbOverlapThreshold,slOverlapThreshold,cbAutoUpdate,btnUpdate]-|
    H:|-[lbMinSize(==33%)]-[lbShiftFactor(==33%)]-[cbFindLandmarks(==20%)][cbAutoUpdate(==10%)]-|
    V:|-[lbMinSize][slMinSize]-[lbMaxSize][slMaxSize]-[lbMinLandmarksScale][slMinLandmarksScale]-|
    V:|-[lbShiftFactor][slShiftFactor]-[lbScaleFactor][slScaleFactor]-[lbPerturbs][slPerturbs]-|
    V:|-[lbAngle][slAngle]-[lbOverlapThreshold][slOverlapThreshold]-[cbFindLandmarks,cbAutoUpdate]-[btnUpdate]-|
  """

slMinSize.wEvent_ScrollThumbTrack do (event: wEvent):
  lbMinSize.label = fmt"Min size: {slMinSize.value}"

slMinSize.wEvent_ScrollChanged do (event: wEvent):
  update()

slMaxSize.wEvent_ScrollThumbTrack do (event: wEvent):
  lbMaxSize.label = fmt"Max size: {slMaxSize.value}"

slMaxSize.wEvent_ScrollChanged do (event: wEvent):
  update()

slMinLandmarksScale.wEvent_ScrollThumbTrack do (event: wEvent):
  lbMinLandmarksScale.label = fmt"Min landmarks scale: {slMinLandmarksScale.value}"

slMinLandmarksScale.wEvent_ScrollChanged do (event: wEvent):
  update()

slShiftFactor.wEvent_ScrollThumbTrack do (event: wEvent):
  lbShiftFactor.label = fmt"Shift factor: {float(slShiftFactor.value) / 1000:.2f}"

slShiftFactor.wEvent_ScrollChanged do (event: wEvent):
  update()

slScaleFactor.wEvent_ScrollThumbTrack do (event: wEvent):
  lbScaleFactor.label = fmt"Scale factor: {float(slScaleFactor.value) / 100:.1f}"

slScaleFactor.wEvent_ScrollChanged do (event: wEvent):
  update()

slPerturbs.wEvent_ScrollThumbTrack do (event: wEvent):
  lbPerturbs.label = fmt"Perturbs: {slPerturbs.value}"

slPerturbs.wEvent_ScrollChanged do (event: wEvent):
  update()

slAngle.wEvent_ScrollThumbTrack do (event: wEvent):
  lbAngle.label = fmt"Angle: {float(slAngle.value) / 10:.1f}deg"

slAngle.wEvent_ScrollChanged do (event: wEvent):
  update()

slOverlapThreshold.wEvent_ScrollThumbTrack do (event: wEvent):
  lbOverlapThreshold.label = fmt"Overlap threshold: {float(slOverlapThreshold.value) / 1000:.2f}"

slOverlapThreshold.wEvent_ScrollChanged do (event: wEvent):
  update()

cbFindLandmarks.wEvent_CheckBox do (event: wEvent):
  update()

cbAutoUpdate.wEvent_CheckBox do (event: wEvent):
  update()

btnUpdate.wEvent_Button do (event: wEvent):
  update(true)

list.wEvent_ListBox do (event: wEvent):
  loadImage(files[list.getSelection])

panel.wEvent_DragEnter do (event: wEvent):
  var dataObject = event.getDataObject()
  if dataObject.isFiles() or dataObject.isBitmap():
    event.setEffect(wDragCopy)
  else:
    event.setEffect(wDragNone)

panel.wEvent_DragOver do (event: wEvent):
  if event.getEffect() != wDragNone:
    if event.ctrlDown:
      event.setEffect(wDragMove)
    else:
      event.setEffect(wDragCopy)

panel.wEvent_Drop do (event: wEvent):
  var dataObject = event.getDataObject()
  if dataObject.isFiles() or dataObject.isBitmap():
    data = DataObject(dataObject)
    if dataObject.isFiles():
      loadImage(dataObject.getFiles()[0])
  else:
    event.setEffect(wDragNone)

frame.idExit do ():
  delete frame

frame.idImage do ():
  let files = FileDialog(frame, message="Select image file to load", wildcard="Image Files (*.jpg;*.jpeg;*.png)|*.jpg;*.jpeg;*.png").display()
  if files.len > 0:
    loadImage(files[0])

panel.wEvent_Size do ():
  layout()

layout()
frame.center()
frame.show()
app.mainLoop()