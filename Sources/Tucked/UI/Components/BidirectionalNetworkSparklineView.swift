import SwiftUI

/// Bidirectional network sparkline displaying upload (pointing up) and download (pointing down) from a center baseline.
public struct BidirectionalNetworkSparklineView: View {
    public let uploadData: [Double]
    public let downloadData: [Double]
    public let uploadColor: Color
    public let downloadColor: Color
    public let capacity: Int
    
    public init(
        uploadData: [Double],
        downloadData: [Double],
        uploadColor: Color = .teal,
        downloadColor: Color = .pink,
        capacity: Int = 90
    ) {
        self.uploadData = uploadData
        self.downloadData = downloadData
        self.uploadColor = uploadColor
        self.downloadColor = downloadColor
        self.capacity = capacity
    }
    
    public var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let midY = size.height / 2.0
            let effectiveCapacity = max(capacity, 2)
            let visibleUpload = Array(uploadData.suffix(effectiveCapacity))
            let visibleDownload = Array(downloadData.suffix(effectiveCapacity))
            
            ZStack {
                // Card background matching native macOS dark panel aesthetic
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(0.04))
                
                // Center baseline dividing upload (above) and download (below)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: midY))
                    path.addLine(to: CGPoint(x: size.width, y: midY))
                }
                .stroke(Color.primary.opacity(0.12), lineWidth: 0.75)
                
                // Upload graph (Top half: spikes growing UP from midY)
                if !visibleUpload.isEmpty {
                    let uploadPoints = calculatePoints(
                        data: visibleUpload,
                        in: size,
                        baselineY: midY,
                        heightAvailable: midY - 3.0,
                        isUpward: true
                    )
                    
                    if let first = uploadPoints.first, let last = uploadPoints.last {
                        // Upload Area Fill - subtle translucent gradient
                        Path { path in
                            path.move(to: CGPoint(x: first.x, y: midY))
                            for pt in uploadPoints {
                                path.addLine(to: pt)
                            }
                            path.addLine(to: CGPoint(x: last.x, y: midY))
                            path.closeSubpath()
                        }
                        .fill(
                            LinearGradient(
                                colors: [uploadColor.opacity(0.14), uploadColor.opacity(0.01)],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                        
                        // Upload Stroke Line - needle-sharp hairline miter trace
                        Path { path in
                            if uploadPoints.count == 1 {
                                path.move(to: CGPoint(x: 0, y: first.y))
                                path.addLine(to: CGPoint(x: size.width, y: first.y))
                            } else {
                                path.move(to: first)
                                for pt in uploadPoints.dropFirst() {
                                    path.addLine(to: pt)
                                }
                            }
                        }
                        .stroke(
                            uploadColor.opacity(0.95),
                            style: StrokeStyle(lineWidth: 1.0, lineCap: .butt, lineJoin: .miter, miterLimit: 10.0)
                        )
                    }
                }
                
                // Download graph (Bottom half: needle spikes growing DOWN from midY)
                if !visibleDownload.isEmpty {
                    let downloadPoints = calculatePoints(
                        data: visibleDownload,
                        in: size,
                        baselineY: midY,
                        heightAvailable: midY - 3.0,
                        isUpward: false
                    )
                    
                    if let first = downloadPoints.first, let last = downloadPoints.last {
                        // Download Area Fill - subtle translucent gradient
                        Path { path in
                            path.move(to: CGPoint(x: first.x, y: midY))
                            for pt in downloadPoints {
                                path.addLine(to: pt)
                            }
                            path.addLine(to: CGPoint(x: last.x, y: midY))
                            path.closeSubpath()
                        }
                        .fill(
                            LinearGradient(
                                colors: [downloadColor.opacity(0.01), downloadColor.opacity(0.14)],
                                startPoint: .center,
                                endPoint: .bottom
                            )
                        )
                        
                        // Download Stroke Line - needle-sharp hairline miter trace
                        Path { path in
                            if downloadPoints.count == 1 {
                                path.move(to: CGPoint(x: 0, y: first.y))
                                path.addLine(to: CGPoint(x: size.width, y: first.y))
                            } else {
                                path.move(to: first)
                                for pt in downloadPoints.dropFirst() {
                                    path.addLine(to: pt)
                                }
                            }
                        }
                        .stroke(
                            downloadColor.opacity(0.95),
                            style: StrokeStyle(lineWidth: 1.0, lineCap: .butt, lineJoin: .miter, miterLimit: 10.0)
                        )
                    }
                }
                
                // Outer Card hairline border
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .frame(height: 52)
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
        let totalSlots = CGFloat(max(capacity, 2) - 1)
        let stepX = size.width / totalSlots
        let startX = max(0, size.width - CGFloat(data.count - 1) * stepX)
        
        return data.enumerated().map { index, value in
            let x = startX + CGFloat(index) * stepX
            let normalized = CGFloat(max(0.0, min(1.0, value / maxVal)))
            let delta = normalized * heightAvailable
            let y = isUpward ? (baselineY - delta) : (baselineY + delta)
            return CGPoint(x: x, y: y)
        }
    }
}

