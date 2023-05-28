import std/monotimes, stats, times
import pixie

import ../src/facedetect

let fc = readFaceCascade()
let image = readImage("tests/testdata/sample.png")

let grayscale = image.grayscale()
let faces = fc.detect(grayscale, minSize = 20, maxSize = 1000, shiftFactor = 0.2, scaleFactor = 1.1, iouThreshold = -1)
echo faces.len
let clustered = faces.cluster(0.1)
echo clustered.len