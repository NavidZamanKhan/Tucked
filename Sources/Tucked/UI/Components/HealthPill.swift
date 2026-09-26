import SwiftUI

/// Compact, restrained status pill component (e.g. [ NORMAL ], [ HEAVY ], [ CRITICAL ]).
public struct HealthPill: View {
    public let text: String
    public let color: Color
    
    public init(text: String, color: Color) {
        self.text = text
        self.color = color
    }
    
    public var body: some View {
        Text("[ \(text) ]")
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .cornerRadius(4)
            .accessibilityLabel("Status: \(text)")
    }
}
