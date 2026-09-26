import SwiftUI

/// Quiet, restrained sparkline component displaying rolling history.
public struct SparklineView: View {
    public let data: [Double]
    public let maxScale: Double?
    public let color: Color
    
    public init(data: [Double], maxScale: Double? = 100.0, color: Color = .accentColor) {
        self.data = data
        self.maxScale = maxScale
        self.color = color
    }
    
    public var body: some View {
        GeometryReader { geometry in
            let points = normalizedPoints(in: geometry.size)
            
            ZStack {
                // Background Area
                Path { path in
                    guard points.count > 1 else { return }
                    path.move(to: CGPoint(x: 0, y: geometry.size.height))
                    for pt in points {
                        path.addLine(to: pt)
                    }
                    path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.2), color.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                
                // Foreground Line
                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for pt in points.dropFirst() {
                        path.addLine(to: pt)
                    }
                }
                .stroke(color.opacity(0.85), lineWidth: 1.5)
            }
        }
        .frame(height: 38)
        .clipped()
    }
    
    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        guard !data.isEmpty else { return [] }
        
        let maxVal: Double
        if let explicitMax = maxScale, explicitMax > 0 {
            maxVal = explicitMax
        } else {
            let actualMax = data.max() ?? 1.0
            maxVal = actualMax > 0 ? actualMax : 1.0
        }
        
        let stepX = data.count > 1 ? size.width / CGFloat(data.count - 1) : size.width
        
        return data.enumerated().map { index, value in
            let x = CGFloat(index) * stepX
            let normalizedY = max(0.0, min(1.0, value / maxVal))
            let y = size.height - (CGFloat(normalizedY) * (size.height - 4)) - 2
            return CGPoint(x: x, y: y)
        }
    }
}
