// Indoor3D/Shared/Extensions/Date+ISO8601.swift

import Foundation

extension Date {
    var iso8601String: String {
        ISO8601DateFormatter().string(from: self)
    }
}

extension DateFormatter {
    static var iso8601: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }
}