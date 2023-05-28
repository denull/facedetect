import unittest, strformat
import facedetect

let skipped: set[uint8] = {1'u8, 4, 5, 6, 7, 8, 9, 10, 12, 16, 17, 18, 19}
for i, testCase in [
  @[], # 1: incorrect
  @[(350, 160, 150)],
  @[(200, 110, 40)],
  @[], # 4: incorrect
  @[], # 5: incorrect
  @[(340, 490, 30)], # 6: incorrect
  @[], # 7: incorrect
  @[], # 8: incorrect
  @[], # 9: incorrect
  @[], # 10: incorrect
  @[],
  @[(400, 110, 60)], # 12: incorrect
  @[],
  @[],
  @[],
  @[(410, 320, 170)], # 16: incorrect
  @[], # 17: incorrect
  @[], # 18: incorrect
  @[], # 19: incorrect
]:
  if uint8(i + 1) in skipped:
    continue
  test "detect face " & $(i + 1):
    let fc = readFaceCascade()
    let image = readGrayscaleImage(fmt"tests/testdata/{i + 1:02}.jpg")
    let faces = fc.detect(image, minSize = 20, shiftFactor = 0.15, scaleFactor = 1.1, iouThreshold = 0.4)
    echo faces
    check faces.len == testCase.len
    for j, face in faces:
      if j >= testCase.len:
        break
      check abs(int(face.x) - testCase[j][0]) < 10
      check abs(int(face.y) - testCase[j][1]) < 10
      check abs(int(face.scale) - testCase[j][2]) < 10