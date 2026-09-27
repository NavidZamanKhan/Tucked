import SwiftUI

/// Bidirectional network sparkline displaying upload (pointing up) and download (pointing down) from a center baseline.
public struct BidirectionalNetworkSparklineView: View {
    public let uploadData: [Double]
    public let downloadData: [Double]
    public let uploadColor: Color
    public let downloadColor: Color
    
    public init(
        uploadData: [Double],
        downloadData: [Double],
        uploadColor: Color = .teal,
        downloadColor: Color = .pink
    ) {
        self.uploadData = uploadData
        self.downloadData = downloadData
        self.uploadColor = uploadColor
        self.downloadColor = downloadColor
    }
    
    public var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let midY = size.height / 2.0
            
            ZStack {
                // Center baseline dividing upload (above) and download (below)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: midY))
                    path.addLine(to: CGPoint(x: size.width, y: midY))
                }
                .stroke(Color.primary.opacity(0.12), lineWidth: 0.75)
                
                // Upload graph (Top half: grows upwards from midY)
                if uploadData.count > 1 {
                    let uploadPoints = calculatePoints(
                        data: uploadData,
                        in: size,
                        baselineY: midY,
                        heightAvailable: midY - 2.0,
                        isUpward: true
                    )
                    
                    // Upload Area Fill
                    Path { path in
                        guard let first = uploadPoints.first, let last = uploadPoints.last else { return }
                        path.move(to: CGPoint(x: first.x, y: midY))
                        for pt in uploadPoints {
                            path.addLine(to: pt)
                        }
                        path.addLine(to: CGPoint(x: last.x, y: midY))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [uploadColor.opacity(0.35), uploadColor.opacity(0.04)],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    
                    // Upload Stroke Line
                    Path { path in
                        guard let first = uploadPoints.first else { return }
                        path.move(to: first)
                        for pt in uploadPoints.dropFirst() {
                            path.addLine(to: pt)
                        }
                    }
                    .stroke(uploadColor.opacity(0.9), lineWidth: 1.5)
                }
                
                // Download graph (Bottom half: grows downwards from midY)
                if downloadData.count > 1 {
                    let downloadPoints = calculatePoints(
                        data: downloadData,
                        in: size,
                        baselineY: midY,
                        heightAvailable: midY - 2.0,
                        isUpward: false
                    )
                    
                    // Download Area Fill
                    Path { path in
                        guard let first = downloadPoints.first, let last = downloadPoints.last else { return }
                        path.move(to: CGPoint(x: first.x, y: midY))
                        for pt in downloadPoints {
                            path.addLine(to: pt)
                        }
                        path.addLine(to: CGPoint(x: last.x, y: midY))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [downloadColor.opacity(0.04), downloadColor.opacity(0.35)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                    )
                    
                    // Download Stroke Line
                    Path { path in
                        guard let first = downloadPoints.first else { return }
                        path.move(to: first)
                        for pt in downloadPoints.dropFirst() {
                            path.addLine(to: pt)
                        }
                    }
                    .stroke(downloadColor.opacity(0.9), lineWidth: 1.5)
                }
            }
        }
        .frame(height: 44)
        .clipped()
    }
    
    private func calculatePoints(
        data: [Double],
        in size: CGSize,
        baselineY: CGFloat,
        heightAvailable: CGFloat,
        isUpward: Bool
    ) -> [CGPoint] {
        guard !data.isEmpty else { return [] }
        
        let maxVal = max(data.max() ?? 1024.0, 1024.0) // At least 1 KB/s minimum scale
        let stepX = data.count > 1 ? size.width / CGFloat(data.count - 1) : size.width
        
        return data.enumerated().map { index, value in
            let x = CGFloat(index) * stepX
            let normalized = CGFloat(max(0.0, min(1.0, value / maxVal)))
            let delta = normalized * heightAvailable
            let y = isUpward ? baselineY - delta : baselineY + delta
            return CGPoint(x: x, y: y)
        }
    }
}
