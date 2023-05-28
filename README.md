# facedetect

A face detection, pupil/eyes localization and facial landmark points detection library.

Port of [Pigo](https://github.com/esimov/pigo). Also uses some tweaks and thresholds from [Photoprism](https://github.com/photoprism/photoprism) (which is using pigo for detecting faces).

API Reference: https://denull.github.io/facedetect/

# Installation

```
nimble install facedetect
```

# Cascade files

This library uses the same cascade file format used by Pigo. Those files available at `cascade` directory, copy it to your app folder so they can be loaded at runtime. Including them statically will be supported later.

# Usage

Although this is a direct port of [Pigo](https://github.com/esimov/pigo), some APIs are a bit different. For example, instead of `Pigo` and `PuplocCascade` structs, this library uses `FaceCascade` and `LandmarkCascade`.

Also there're two APIs: low-level procs, which allow to separately detect faces, eyes and other landmark features, and a bit higher-level `FaceDetector`, which does everything in one go. Using `FaceDetector` is recommended, as it also applies some extra filtering on the results.

Example:

```nim
import facedetect

let fd = initFaceDetector() # This will load all cascade files from `cascade` directory
let image = readGrayscaleImage("sample.jpg") # Load image (using pixie) and convert it to grayscale
let people = fd.detect(image, minSize = 20, shiftFactor = 0.1, scaleFactor = 1.1)
for i, person in people:
  echo "Found face at ", person.face.x, ", ", person.face.y
```

There's also a demo app in `cmd/demo.nim` (but it uses wNim library, so it's Windows-only). For an example of cross-platform usage of lower-level (only face detection), see `cmd/test.nim`.

# Benchmark

For benchmarking I replicated code from https://github.com/esimov/pigo-gocv-benchmark. It's available in `demo/benchmark.nim` Depending on compilation flags, it gives following results on my machine:

```
nim c -r cmd/benchmark (DEBUG build):                       180ms
nim c -d:release -r cmd/benchmark (RELEASE build):          52ms
nim c -d:danger --passC:"-O3 -flto -m64" -r cmd/benchmark:  50ms
```

For comparison, this is Go implementations:

```
cpu: AMD Ryzen 5 3600 6-Core Processor
BenchmarkGoCV-12              10         106933090 ns/op
BenchmarkPIGO-12              14          81145464 ns/op
```

So `facedetect` (with maximal optimisations enabled) seems to work about 38% faster than PIGO and 53% faster than GoCV. I should note, however, that this benchmark covers only the basic face detection (eyes/landmark detection is not included).