import ../src/facedetect
import strformat, strutils, os, times, tables
import pixie

import wNim/[wApp, wDataObject, wAcceleratorTable, wUtils,
  wFrame, wPanel, wMenuBar, wMenu, wIcon, wImage, wBitmap,
  wStatusBar, wStaticText, wTextCtrl, wListBox, wStaticBitmap, wMemoryDC, wStaticBox, wPaintDC, wBrush, wPen]

type
  MenuID = enum
    idImage = wIdUser, idExit

  ImageInfo = object
    fname: string
    name: string
    image: pixie.Image

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

let infobox = StaticBox(panel, label="Info")
let infoLabel = StaticText(infobox, label="")

let list = ListBox(panel, style=wLbSingle or wLbNeededScroll)
let imagePanel = Panel(panel)
#let image = StaticBitmap(panel, style=wSbCenter)
var info = ImageInfo()
var currentBitmap: wBitmap
var currentPeople: seq[Person] = @[]

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

  dc.drawBitmap(currentBitmap, 0, 0)
  for person in currentPeople:
    let face = person.face
    dc.pen = Pen(color=0xFF3030, width=3)
    dc.drawRoundedRectangle(int(face.x - (face.scale / 2)), int(face.y - (face.scale / 2)), int(face.scale), int(face.scale), 5)
    for eye in person.eyes:
      if isNil(eye):
        continue
      dc.pen = Pen(color=0x3030FF, width=3)
      dc.drawRoundedRectangle(int(eye.x - (eye.scale / 2)), int(eye.y - (eye.scale / 2)), int(eye.scale), int(eye.scale), 5)
    for name, landmark in person.landmarks:
      dc.pen = Pen(color=0x30FFFF, width=3)
      let sz = 1
      dc.drawRoundedRectangle(int(landmark.x) - sz, int(landmark.y) - sz, sz * 2, sz * 2, 5)

proc loadImage(fname: string) =
  echo fmt"Loading file {fname}"
  currentBitmap = Bitmap(Image(fname))

  var st = epochTime()
  let grayImage = readGrayscaleImage(fname)
  echo fmt"Image loaded in {epochTime() - st}s ({currentBitmap.width}x{currentBitmap.height} ~{currentBitmap.width*currentBitmap.height div 1000000} MP)"
  st = epochTime()
  #currentFaces = fc.detect(grayImage)
  #currentFaces = fc.detect(grayImage, minSize = 20, shiftFactor = 0.1, scaleFactor = 1.1, iouThreshold = 0.41)
  currentPeople = detector.detect(grayImage)
  echo fmt"Faces detected in {epochTime() - st}s"
  echo currentPeople

  let parts = split(fname, '\\')
  info = ImageInfo(
    fname: fname,
    name: split(parts[^1], '.')[0],
    image: readImage(fname),
  )
  imagePanel.refresh(true)

proc layout() =
  panel.autolayout """
    spacing: 15
    H:|-[label,list(500)]-[imagePanel,infobox]-|
    V:|-[label][list]-|
    V:|-[imagePanel(1000)]-[infobox]-|
  """

  infobox.autolayout """
    H:|-[infoLabel]-|
    V:|-[infoLabel]-|
  """

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
  # TODO: load image
  discard

panel.wEvent_Size do ():
  layout()

layout()
frame.center()
frame.show()
app.mainLoop()