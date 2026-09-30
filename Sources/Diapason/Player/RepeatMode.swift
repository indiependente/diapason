enum RepeatMode: String, CaseIterable, Sendable {
    case off
    case all
    case one

    var title: String {
        switch self {
        case .off: "Off"
        case .all: "All"
        case .one: "One"
        }
    }

    var systemImage: String {
        self == .one ? "repeat.1" : "repeat"
    }

    /// Off, then all, then one, then off again.
    var next: RepeatMode {
        let all = Self.allCases

        return all[(all.firstIndex(of: self).map { $0 + 1 } ?? 0) % all.count]
    }
}
