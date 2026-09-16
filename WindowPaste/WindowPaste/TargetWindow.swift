import Foundation

struct TargetWindow: Identifiable, Equatable, Hashable {
    let windowID: UInt32
    let title: String
    let width: Int
    let height: Int
    let isOnScreen: Bool

    var id: UInt32 { windowID }

    var displayName: String {
        let size = "\(width)×\(height)"
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "未命名窗口  \(size)"
        }
        return "\(trimmed)  \(size)"
    }

    var shortName: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "未命名窗口" : trimmed
    }
}
