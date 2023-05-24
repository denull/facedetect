import streams, endians

when system.cpuEndian == bigEndian:
  proc readUint16be*(stream: Stream): uint16 = readUint16(stream)
  proc readUint16le*(stream: Stream): uint16 =
    let value = readUint16(stream)
    swapEndian16(addr result, unsafeAddr value)
  
  proc readUint32be*(stream: Stream): uint32 = readUint32(stream)
  proc readUint32le*(stream: Stream): uint32 =
    let value = readUint32(stream)
    swapEndian32(addr result, unsafeAddr value)

  proc readUint64be*(stream: Stream): uint64 = readUint64(stream)
  proc readUint64le*(stream: Stream): uint64 =
    let value = readUint64(stream)
    swapEndian64(addr result, unsafeAddr value)

  proc readInt32be*(stream: Stream): int32 = readInt32(stream)
  proc readInt32le*(stream: Stream): int32 =
    let value = readInt32(stream)
    swapEndian32(addr result, unsafeAddr value)

  proc readFloat32be*(stream: Stream): float32 = readFloat32(stream)
  proc readFloat32le*(stream: Stream): float32 =
    let value = readFloat32(stream)
    swapEndian32(addr result, unsafeAddr value)

  proc readFloat64be*(stream: Stream): float64 = readFloat64(stream)
  proc readFloat64le*(stream: Stream): float64 =
    let value = readFloat64(stream)
    swapEndian64(addr result, unsafeAddr value)
else:
  proc readUint16le*(stream: Stream): uint16 = readUint16(stream)
  proc readUint16be*(stream: Stream): uint16 =
    let value = readUint16(stream)
    swapEndian16(addr result, unsafeAddr value)

  proc readUint32le*(stream: Stream): uint32 = readUint32(stream)
  proc readUint32be*(stream: Stream): uint32 =
    let value = readUint32(stream)
    swapEndian32(addr result, unsafeAddr value)

  proc readUint64le*(stream: Stream): uint64 = readUint64(stream)
  proc readUint64be*(stream: Stream): uint64 =
    let value = readUint64(stream)
    swapEndian64(addr result, unsafeAddr value)

  proc readInt32le*(stream: Stream): int32 = readInt32(stream)
  proc readInt32be*(stream: Stream): int32 =
    let value = readInt32(stream)
    swapEndian32(addr result, unsafeAddr value)

  proc readFloat32le*(stream: Stream): float32 = readFloat32(stream)
  proc readFloat32be*(stream: Stream): float32 =
    let value = readFloat32(stream)
    swapEndian32(addr result, unsafeAddr value)

  proc readFloat64le*(stream: Stream): float64 = readFloat64(stream)
  proc readFloat64be*(stream: Stream): float64 =
    let value = readFloat64(stream)
    swapEndian64(addr result, unsafeAddr value)

proc readUint16*(stream: Stream, bigEndian: bool): uint16 =
  if bigEndian: readUint16be(stream) else: readUint16le(stream)
proc readUint32*(stream: Stream, bigEndian: bool): uint32 =
  if bigEndian: readUint32be(stream) else: readUint32le(stream)
proc readUint64*(stream: Stream, bigEndian: bool): uint64 =
  if bigEndian: readUint64be(stream) else: readUint64le(stream)
proc readInt32*(stream: Stream, bigEndian: bool): int32 =
  if bigEndian: readInt32be(stream) else: readInt32le(stream)
proc readFloat32*(stream: Stream, bigEndian: bool): float32 =
  if bigEndian: readFloat32be(stream) else: readFloat32le(stream)
proc readFloat64*(stream: Stream, bigEndian: bool): float64 =
  if bigEndian: readFloat64be(stream) else: readFloat64le(stream)
