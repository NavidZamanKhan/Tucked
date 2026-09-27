import SwiftUI

/// Pixel-matched skeleton placeholder row for processes during diagnostics sampling.
public struct ProcessSkeletonRowView: View {
    public let nameWidth: CGFloat
    public let metricWidth: CGFloat
    
    public init(nameWidth: CGFloat = 80, metricWidth: CGFloat = 34) {
        self.nameWidth = nameWidth
        self.metricWidth = metricWidth
    }
    
    public var body: some View {
        HStack(spacing: 6) {
            // Icon placeholder
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color.primary.opacity(0.08))
                .frame(width: 14, height: 14)
            
            // Name placeholder
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color.primary.opacity(0.07))
                .frame(width: nameWidth, height: 10)
            
            Spacer()
            
            // Metric placeholder
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color.primary.opacity(0.07))
                .frame(width: metricWidth, height: 10)
            
            // Reserved quit button slot
            Color.clear
                .frame(width: 16, height: 16)
        }
        .frame(height: 20)
    }
}
