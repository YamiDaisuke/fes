import JavaScriptEventLoop
import JavaScriptKit

func fileBytes(_ file: JSValue) async throws(JSException) -> [UInt8] {
    let buffer = try await JSPromise(file.arrayBuffer().object!)!.value
    let view = JSTypedArray<UInt8>(unsafelyWrapping: JSObject.global.Uint8Array.function!.new(buffer))
    return view.withUnsafeBytes { Array($0) }
}
