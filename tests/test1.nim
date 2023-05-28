import unittest
import facedetect

for i, testCase in [
  @[(350, 160, 170), (350, 160, 140), (105, 220, 20)], # 1: not ok; should be two faces
  @[(162, 350, 151)], # 2: ok
  @[], # 3: WRONG: should be 1 face
  @[(180, 379, 155)], # 4: ok
  @[(219, 366, 122)], # 5: ok
  @[], # 6: WRONG: should be 1 face
  @[], # 7: ok
  @[], # 8: WRONG (but hard): should be 1 face
  @[], # 9: ok
  @[(92, 617, 115)], # 10: WRONG (if we don't want to track dogs in sunglasses): should be 0 faces
  @[], # 11: ok?
  @[], # 12: WRONG: should be 1 face
  @[], # 13: ok
  @[], # 14: ok
  @[], # 15: ok
  @[(316, 414, 172)], # 16: WRONG: should be 2 faces
  @[(351, 289, 232)], # 17: WRONG: should be 2 faces
  @[(295, 263, 219)], # 18: WRONG: should be 2 faces
  @[(385, 367, 121)], # 19: WRONG: should be 0 faces
]:
  test "detect face " & $(i + 1):
    let fc = readFaceCascade()
    let image = readGrayscaleImage("tests/testdata/" & $(i + 1) & ".jpg")
    let faces = fc.detect(image, minSize = 20, shiftFactor = 0.1, scaleFactor = 1.1)
    echo faces
    check faces.len == testCase.len
    for j, face in faces:
      if j >= testCase.len:
        break
      check abs(int(face.x) - testCase[j][0]) < 10
      check abs(int(face.y) - testCase[j][1]) < 10
      check abs(int(face.scale) - testCase[j][2]) < 10