@testable import Diapason
import Testing

@Suite("RepeatMode")
struct RepeatModeTests {
    @Test("cycles off, all, one, off")
    func cycles() {
        #expect(RepeatMode.off.next == .all)
        #expect(RepeatMode.all.next == .one)
        #expect(RepeatMode.one.next == .off)
    }
}
