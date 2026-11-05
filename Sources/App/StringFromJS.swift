import JavaScriptKit

nonisolated(unsafe) private let textEncoder = JSObject.global.TextEncoder.function!.new()

// JavaScriptKit's JSValue.string decodes through a C string and stops at U+0000 (decision 018).
func string(from value: JSValue) -> String? {
    guard value.jsString != nil else { return nil }
    let bytes = JSTypedArray<UInt8>(unsafelyWrapping: textEncoder.encode!(value).object!)
    return bytes.withUnsafeBytes { String(decoding: $0, as: UTF8.self) }
}
