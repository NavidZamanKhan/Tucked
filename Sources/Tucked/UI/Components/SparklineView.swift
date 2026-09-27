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

            let baselineY = floor((size.height - 2.0 * pixel) * scale) * pixel
            let usableHeight = max(baselineY - (2.0 * pixel), 1.0)
            let totalSlots = CGFloat(effectiveCapacity)
            let slotWidth = size.width / totalSlots
            let startX = max(0, size.width - CGFloat(visibleData.count) * slotWidth)

            var idleBarsPath = Path()
            var activeBarsPath = Path()

            for (index, value) in visibleData.enumerated() {
                let rawX = startX + (CGFloat(index) + 0.5) * slotWidth
                let barX = (floor(rawX * scale) + 0.5) * pixel

                let normalized = max(0.0, min(1.0, value / maxVal))
                let rawHeight = CGFloat(normalized) * usableHeight
                // Minimum 1-pixel tick so idle telemetry creates visible comb teeth
                let barHeight = max(pixel, ceil(rawHeight * scale) * pixel)
                let barY = baselineY - barHeight

                if normalized < 0.05 {
                    idleBarsPath.move(to: CGPoint(x: barX, y: baselineY))
                    idleBarsPath.addLine(to: CGPoint(x: barX, y: barY))
                } else {
                    activeBarsPath.move(to: CGPoint(x: barX, y: baselineY))
                    activeBarsPath.addLine(to: CGPoint(x: barX, y: barY))
                }
            }

            let strokeStyle = StrokeStyle(lineWidth: pixel, lineCap: .butt)
            if !idleBarsPath.isEmpty {
                context.stroke(idleBarsPath, with: .color(color.opacity(0.38)), style: strokeStyle)
            }
            if !activeBarsPath.isEmpty {
                context.stroke(activeBarsPath, with: .color(color.opacity(0.85)), style: strokeStyle)
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

