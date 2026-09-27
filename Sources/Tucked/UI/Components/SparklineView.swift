import SwiftUI

/// Quiet, restrained sparkline component displaying rolling history edge-to-edge inside its card housing.
public struct SparklineView: View {
    public let data: [Double]
    public let maxScale: Double?
    public let color: Color
    public let capacity: Int

    public init(
        data: [Double],
        maxScale: Double? = 100.0,
        color: Color = .accentColor,
        capacity: Int = 90
    ) {
        self.data = data
        self.maxScale = maxScale
        self.color = color
        self.capacity = capacity
    }

    public var body: some View {
        Canvas { context, size in
            let scale = context.environment.displayScale
            let pixel = scale > 0 ? (1.0 / scale) : 1.0

            let effectiveCapacity = max(capacity, 2)
            let visibleData = Array(data.suffix(effectiveCapacity))
            guard !visibleData.isEmpty else { return }

            let maxVal: Double
            if let explicitMax = maxScale, explicitMax > 0 {
                maxVal = explicitMax
            } else {
                maxVal = 100.0
            }

            let baselineY = (floor((size.height - 2.0 * pixel) * scale)) * pixel
            let usableHeight = max(baselineY - (2.0 * pixel), 1.0)
            let totalSlots = CGFloat(effectiveCapacity)
            let slotWidth = size.width / totalSlots

            // Ultra-thin bar width with tight comb spacing
            let rawBarWidth = max(pixel, slotWidth * 0.55)
            let barWidth = max(pixel, round(rawBarWidth * scale) * pixel)
            let startX = max(0, size.width - CGFloat(visibleData.count) * slotWidth)

            for (index, value) in visibleData.enumerated() {
                let rawX = startX + CGFloat(index) * slotWidth + (slotWidth - barWidth) / 2.0
                let barX = round(rawX * scale) * pixel

                let normalized = max(0.0, min(1.0, value / maxVal))
                let rawHeight = CGFloat(normalized) * usableHeight
                // Minimum 1-pixel tick so idle values create visible comb teeth
                let barHeight = max(pixel, ceil(rawHeight * scale) * pixel)
                let barY = baselineY - barHeight

                let barRect = CGRect(x: barX, y: barY, width: barWidth, height: barHeight)
                context.fill(Path(barRect), with: .color(color))
            }
        }
        .frame(height: 38)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.primary.opacity(0.03))
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.black.opacity(0.15))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}

