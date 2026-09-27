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
        GeometryReader { geometry in
            let size = geometry.size
            let baselineY = size.height - 1.0
            let effectiveCapacity = max(capacity, 2)
            let visibleData = Array(data.suffix(effectiveCapacity))
            let points = calculatePoints(data: visibleData, in: size, baselineY: baselineY)
            
            ZStack {
                // Card background matching native macOS dark panel aesthetic
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.primary.opacity(0.04))
                
                // Subtle 50% guide line
                Path { path in
                    let midGuideY = size.height / 2.0
                    path.move(to: CGPoint(x: 0, y: midGuideY))
                    path.addLine(to: CGPoint(x: size.width, y: midGuideY))
                }
                .stroke(Color.primary.opacity(0.05), lineWidth: 0.5)
                
                // Bottom baseline
                Path { path in
                    path.move(to: CGPoint(x: 0, y: baselineY))
                    path.addLine(to: CGPoint(x: size.width, y: baselineY))
                }
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                
                if !points.isEmpty {
                    let first = points[0]
                    let last = points[points.count - 1]
                    
                    // Background Area Fill
                    Path { path in
                        path.move(to: CGPoint(x: first.x, y: baselineY))
                        for pt in points {
                            path.addLine(to: pt)
                        }
                        path.addLine(to: CGPoint(x: last.x, y: baselineY))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.32), color.opacity(0.03)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    // Foreground Stroke Line
                    Path { path in
                        if points.count == 1 {
                            path.move(to: CGPoint(x: 0, y: first.y))
                            path.addLine(to: CGPoint(x: size.width, y: first.y))
                        } else {
                            path.move(to: first)
                            for pt in points.dropFirst() {
                                path.addLine(to: pt)
                            }
                        }
                    }
                    .stroke(
                        color.opacity(0.95),
                        style: StrokeStyle(lineWidth: 1.25, lineCap: .round, lineJoin: .round)
                    )
                }
                
                // Outer Card hairline border
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .frame(height: 38)
    }
    
    private func calculatePoints(data: [Double], in size: CGSize, baselineY: CGFloat) -> [CGPoint] {
        guard !data.isEmpty else { return [] }
        
        let maxVal: Double
        if let explicitMax = maxScale, explicitMax > 0 {
            maxVal = explicitMax
        } else {
            let actualMax = data.max() ?? 100.0
            maxVal = actualMax > 0 ? actualMax : 100.0
        }
        
        let stepX = data.count > 1 ? size.width / CGFloat(data.count - 1) : size.width
        let usableHeight = size.height - 4.0
        
        return data.enumerated().map { index, value in
            let x = CGFloat(index) * stepX
            let normalizedY = max(0.0, min(1.0, value / maxVal))
            let y = baselineY - (CGFloat(normalizedY) * usableHeight)
            return CGPoint(x: x, y: y)
        }
    }
}

