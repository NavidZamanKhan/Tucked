import SwiftUI

/// Quiet, restrained sparkline component displaying rolling history edge-to-edge inside its card housing.
public struct SparklineView: View {
    public let data: [Double?]
    public let maxScale: Double?
    public let color: Color
    public let capacity: Int

    public init(
        data: [Double?],
        maxScale: Double? = 100.0,
        color: Color = .accentColor,
        capacity: Int = 90
    ) {
        self.data = data
        self.maxScale = maxScale
        self.color = color
        self.capacity = capacity
    }

    public init(
        data: [Double],
        maxScale: Double? = 100.0,
        color: Color = .accentColor,
        capacity: Int = 90
    ) {
        self.data = data.map { Optional($0) }
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

            let maxVal: Double = (maxScale != nil && maxScale! > 0) ? maxScale! : 100.0

            let topInset: CGFloat = 2.0 * pixel
            let baselineY = floor((size.height - 2.0 * pixel) * scale) * pixel
            let usableHeight = max(baselineY - topInset, 1.0)

            let stepX = size.width / CGFloat(effectiveCapacity - 1)
            let startX = max(0, size.width - CGFloat(visibleData.count - 1) * stepX)

            var segments: [[CGPoint]] = []
            var currentSegment: [CGPoint] = []

            for (index, maybeValue) in visibleData.enumerated() {
                guard let value = maybeValue else {
                    if !currentSegment.isEmpty {
                        segments.append(currentSegment)
                        currentSegment = []
                    }
                    continue
                }

                let rawX = startX + CGFloat(index) * stepX
                let alignedX = floor(rawX * scale) * pixel
                let normalized = CGFloat(max(0.0, min(1.0, value / maxVal)))
                let rawY = baselineY - (normalized * usableHeight)
                let alignedY = floor(rawY * scale + 0.5) * pixel
                currentSegment.append(CGPoint(x: alignedX, y: alignedY))
            }
            if !currentSegment.isEmpty {
                segments.append(currentSegment)
            }

            guard !segments.isEmpty else { return }

            let fillShading = GraphicsContext.Shading.linearGradient(
                Gradient(colors: [
                    color.opacity(0.35),
                    color.opacity(0.08)
                ]),
                startPoint: CGPoint(x: 0, y: topInset),
                endPoint: CGPoint(x: 0, y: baselineY)
            )

            let strokeStyle = StrokeStyle(
                lineWidth: pixel,
                lineCap: .round,
                lineJoin: .round
            )

            for segment in segments {
                if segment.count >= 2 {
                    // Area fill with subtle vertical gradient fading toward baseline
                    var areaPath = Path()
                    areaPath.move(to: CGPoint(x: segment[0].x, y: baselineY))
                    areaPath.addLine(to: segment[0])
                    for i in 1..<segment.count {
                        areaPath.addLine(to: segment[i])
                    }
                    areaPath.addLine(to: CGPoint(x: segment[segment.count - 1].x, y: baselineY))
                    areaPath.closeSubpath()
                    context.fill(areaPath, with: fillShading)

                    // Razor-sharp hairline boundary stroke
                    var strokePath = Path()
                    strokePath.move(to: segment[0])
                    for i in 1..<segment.count {
                        strokePath.addLine(to: segment[i])
                    }
                    context.stroke(strokePath, with: .color(color.opacity(0.95)), style: strokeStyle)
                } else if segment.count == 1 {
                    // Single point needle
                    var singlePath = Path()
                    singlePath.move(to: CGPoint(x: segment[0].x, y: baselineY))
                    singlePath.addLine(to: segment[0])
                    context.stroke(singlePath, with: .color(color.opacity(0.95)), style: strokeStyle)
                }
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

