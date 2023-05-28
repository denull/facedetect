# facedetect

A face detection, pupil/eyes localization and facial landmark points detection library.

Port of [pigo](https://github.com/esimov/pigo). Also uses some tweaks and thresholds from [Photoprism](https://github.com/photoprism/photoprism) (which is using pigo for detecting faces).



# Benchmark

For benchmarking I replicated code from https://github.com/esimov/pigo-gocv-benchmark. It's available in `demo/benchmark.nim` Depending on compilation flags, it gives following results on my machine:

```
nim c -r demo/benchmark (DEBUG build):                       419ms
nim c -d:release -r demo/benchmark (RELEASE build):          73ms
nim c -d:danger -r demo/benchmark:                           54ms
nim c -d:danger --passC:"-O3 -flto -m64" -r demo/benchmark:  50ms
```

For comparison, this is Go implementations:

```
cpu: AMD Ryzen 5 3600 6-Core Processor
BenchmarkGoCV-12              10         106933090 ns/op
BenchmarkPIGO-12              14          81145464 ns/op
```

So `facedetect` (with maximal optimisations enabled) seems to work about 43% faster than PIGO and 57% faster than GoCV. I should note, however, that this benchmark covers only the basic face detection (eyes/landmark detection is not included).