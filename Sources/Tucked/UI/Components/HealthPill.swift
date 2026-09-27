import SwiftUI

/// Elegant 3-option status indicator with respective color illumination.
public struct HealthStatusIndicator: View {
    public struct Option: Identifiable, Equatable {
        public let id: Int
        public let label: String
        public let color: Color
        
        public init(id: Int, label: String, color: Color) {
            self.id = id
            self.label = label
            self.color = color
        }
    }
    
    public let options: [Option]
    public let selectedIndex: Int
    
    public init(options: [Option], selectedIndex: Int) {
        self.options = options
        self.selectedIndex = selectedIndex
    }
    
    public var body: some View {
        HStack(spacing: 2) {
            ForEach(options) { opt in
                let isSelected = opt.id == selectedIndex
                Text(opt.label)
                    .font(.system(size: 8.5, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? opt.color : Color.primary.opacity(0.38))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                            .fill(isSelected ? opt.color.opacity(0.14) : Color.clear)
                    )
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .animation(.easeInOut(duration: 0.2), value: selectedIndex)
    }
}

// MARK: - Convenience Initializers for Domain Health States

extension HealthStatusIndicator {
    public static func cpu(status: CPUHealthStatus) -> HealthStatusIndicator {
        let options = [
            Option(id: 0, label: "Normal", color: .green),
            Option(id: 1, label: "Heavy", color: .yellow),
            Option(id: 2, label: "Critical", color: .red)
        ]
        let index: Int
        switch status {
        case .normal: index = 0
        case .heavy: index = 1
        case .critical: index = 2
        }
        return HealthStatusIndicator(options: options, selectedIndex: index)
    }
    
    public static func memory(status: MemoryHealthStatus) -> HealthStatusIndicator {
        let options = [
            Option(id: 0, label: "Normal", color: .green),
            Option(id: 1, label: "Heavy", color: .yellow),
            Option(id: 2, label: "Critical", color: .red)
        ]
        let index: Int
        switch status {
        case .normal: index = 0
        case .heavy: index = 1
        case .critical: index = 2
        }
        return HealthStatusIndicator(options: options, selectedIndex: index)
    }
    
    public static func network(status: NetworkHealthStatus) -> HealthStatusIndicator {
        let options = [
            Option(id: 0, label: "Stable", color: .green),
            Option(id: 1, label: "Degraded", color: .yellow),
            Option(id: 2, label: "Offline", color: .red)
        ]
        let index: Int
        switch status {
        case .stable: index = 0
        case .checking, .degraded: index = 1
        case .poor, .offline: index = 2
        }
        return HealthStatusIndicator(options: options, selectedIndex: index)
    }
}

/// Backwards compatibility alias
public typealias HealthPill = HealthStatusIndicator
