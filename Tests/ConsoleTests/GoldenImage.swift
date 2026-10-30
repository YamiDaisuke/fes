import Console
import Foundation
import Testing

func expectFrameMatchesGolden(
    _ frame: Framebuffer,
    named name: String,
    sourceLocation: SourceLocation = #_sourceLocation
) throws {
    let goldenDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Golden")
    let goldenURL = goldenDirectory.appendingPathComponent("\(name).png")
    let actualURL = goldenDirectory.appendingPathComponent("\(name).actual.png")
    let png = Data(pngData(rgba: frame.rgba, width: Screen.width, height: Screen.height))

    if ProcessInfo.processInfo.environment["FES_RECORD_GOLDENS"] == "1" {
        try png.write(to: goldenURL)
        Issue.record("Recorded \(goldenURL.path), run again without FES_RECORD_GOLDENS", sourceLocation: sourceLocation)
        return
    }

    guard let golden = FileManager.default.contents(atPath: goldenURL.path) else {
        try png.write(to: actualURL)
        Issue.record(
            """
            Golden \(goldenURL.path) is missing.
            Actual frame written to \(actualURL.path).
            Record it with FES_RECORD_GOLDENS=1 swift test.
            """,
            sourceLocation: sourceLocation
        )
        return
    }

    if golden == png {
        try? FileManager.default.removeItem(at: actualURL)
        return
    }

    try png.write(to: actualURL)
    Issue.record(
        """
        Frame does not match golden \(goldenURL.path).
        Actual frame written to \(actualURL.path).
        If the change is intended, re-record with FES_RECORD_GOLDENS=1 swift test.
        """,
        sourceLocation: sourceLocation
    )
}
