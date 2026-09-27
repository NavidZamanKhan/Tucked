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

            // Helper to center a 1-pixel stroke squarely on physical pixel boundary
            func alignStroke(_ val: CGFloat) -> CGFloat {
                return (floor(val * scale) + 0.5) * pixel
            }

            // Helper to snap vertex to physical pixel grid
            func snapCoord(_ val: CGFloat) -> CGFloat {
                return round(val * scale) * pixel
            }

            let baselineY = alignStroke(size.height - 1.5 * pixel)
            let midGuideY = alignStroke(size.height / 2.0)

            // 50% Mid Guide - fine dotted 1-pixel graticule
            var midGuidePath = Path()
            midGuidePath.move(to: CGPoint(x: 0, y: midGuideY))
            midGuidePath.addLine(to: CGPoint(x: size.width, y: midGuideY))
            context.stroke(
                midGuidePath,
                with: .color(Color.primary.opacity(0.06)),
                style: StrokeStyle(lineWidth: pixel, lineCap: .square, dash: [pixel, pixel * 3])
            )

            // Baseline - crisp 1-pixel datum rule
            var baselinePath = Path()
            baselinePath.move(to: CGPoint(x: 0, y: baselineY))
            baselinePath.addLine(to: CGPoint(x: size.width, y: baselineY))
            context.stroke(
                baselinePath,
                with: .color(Color.primary.opacity(0.12)),
                style: StrokeStyle(lineWidth: pixel, lineCap: .butt)
            )

            let effectiveCapacity = max(capacity, 2)
            let visibleData = Array(data.suffix(effectiveCapacity))
            guard !visibleData.isEmpty else { return }

            let maxVal: Double
            if let explicitMax = maxScale, explicitMax > 0 {
                maxVal = explicitMax
            } else {
                let peak = visibleData.max() ?? 0.0
                if peak <= 25.0 {
                    maxVal = 25.0
                } else if peak <= 50.0 {
                    maxVal = 50.0
                } else {
                    maxVal = 100.0
                }
            }

            let usableHeight = max(baselineY - (3.0 * pixel), 1.0)
            let totalSlots = CGFloat(effectiveCapacity - 1)
            let stepX = size.width / totalSlots
            let startX = max(0, size.width - CGFloat(visibleData.count - 1) * stepX)

            var points = [CGPoint]()
            points.reserveCapacity(visibleData.count)

            for (index, value) in visibleData.enumerated() {
                let rawX = startX + CGFloat(index) * stepX
                let normalizedY = max(0.0, min(1.0, value / maxVal))
                let rawY = baselineY - (CGFloat(normalizedY) * usableHeight)
                points.append(CGPoint(x: snapCoord(rawX), y: snapCoord(rawY)))
            }

            var tracePath = Path()
            if visibleData.count == 1 {
                let y = alignStroke(baselineY - (CGFloat(max(0.0, min(1.0, visibleData[0] / maxVal))) * usableHeight))
                tracePath.move(to: CGPoint(x: startX, y: y))
                tracePath.addLine(to: CGPoint(x: size.width, y: y))
            } else if let first = points.first {
                tracePath.move(to: first)
                for pt in points.dropFirst() {
                    tracePath.addLine(to: pt)
                }
            }

            // Precision hairline trace (1 physical device pixel)
            let traceStyle = StrokeStyle(
                lineWidth: pixel,
                lineCap: .butt,
                lineJoin: .miter,
                miterLimit: 10.0
            )
            context.stroke(tracePath, with: .color(color), style: traceStyle)
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

