import Console
import GoldenImage
import Testing

@Test func testSceneAtFrame60MatchesGolden() throws {
    var scene = TestScene()
    var frame = Framebuffer()
    scene.render(frame: 60, input: Input(), into: &frame)
    try expectFrameMatchesGolden(frame, named: "test-scene-frame-60")
}
