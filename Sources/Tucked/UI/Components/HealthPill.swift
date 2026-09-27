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
    public let alignment: HorizontalAlignment
    
    public init(options: [Option], selectedIndex: Int, alignment: HorizontalAlignment = .leading) {
        self.options = options
        self.selectedIndex = selectedIndex
        self.alignment = alignment
    }
    
    public var body: some View {
        VStack(alignment: alignment, spacing: 1.5) {
            ForEach(options) { opt in
                let isSelected = opt.id == selectedIndex
                Text(opt.label)
                    .font(.system(size: 8, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? opt.color : Color.primary.opacity(0.30))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: selectedIndex)
    }
}

// MARK: - Convenience Initializers for Domain Health States

extension HealthStatusIndicator {
    public static func cpu(status: CPUHealthStatus, alignment: HorizontalAlignment = .leading) -> HealthStatusIndicator {
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
        return HealthStatusIndicator(options: options, selectedIndex: index, alignment: alignment)
    }
    
    public static func memory(status: MemoryHealthStatus, alignment: HorizontalAlignment = .leading) -> HealthStatusIndicator {
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
        return HealthStatusIndicator(options: options, selectedIndex: index, alignment: alignment)
    }
    
    public static func network(status: NetworkHealthStatus, alignment: HorizontalAlignment = .trailing) -> HealthStatusIndicator {
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
        return HealthStatusIndicator(options: options, selectedIndex: index, alignment: alignment)
    }
}

/// Backwards compatibility alias
public typealias HealthPill = HealthStatusIndicator
