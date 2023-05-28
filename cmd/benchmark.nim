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
    echo "Run ", iterations, "/10, ", int(float(sum) / float(reps)), " faces detected"
  echo r

# BenchmarkGoCV-12              10         106933090 ns/op (106ms)
# BenchmarkPIGO-12              14          81145464 ns/op (81ms)
#
# nim c -r cmd/benchmark (DEBUG build):                       180ms
# nim c -d:release -r cmd/benchmark (RELEASE build):          52ms
# nim c -d:danger --passC:"-O3 -flto -m64" -r cmd/benchmark:  50ms