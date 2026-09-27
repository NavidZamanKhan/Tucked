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
    
    private struct SparklineSegment {
        let points: [CGPoint]
    }
    
    public var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let midY = size.height / 2.0
            let effectiveCapacity = max(capacity, 2)
            let visibleUpload = Array(uploadData.suffix(effectiveCapacity))
            let visibleDownload = Array(downloadData.suffix(effectiveCapacity))
            let peakUpload = visibleUpload.max() ?? 0.0
            let peakDownload = visibleDownload.max() ?? 0.0
            
            ZStack(alignment: .topLeading) {
                // Card background and border matching native macOS dark panel aesthetic
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(0.04))
                
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                
                // Center baseline dividing upload (above) and download (below)
                Path { path in
                    path.move(to: CGPoint(x: 3, y: midY))
                    path.addLine(to: CGPoint(x: size.width - 3, y: midY))
                }
                .stroke(Color.primary.opacity(0.14), lineWidth: 0.75)
                
                // Upload graph (Top half: needle spikes growing UP from midY)
                if !visibleUpload.isEmpty {
                    let uploadBaselineY = midY - 0.75
                    let uploadPoints = calculatePoints(
                        data: visibleUpload,
                        in: size,
                        baselineY: uploadBaselineY,
                        heightAvailable: midY - 6.0,
                        isUpward: true
                    )
                    let uploadSegments = extractSegments(points: uploadPoints, values: visibleUpload, baselineY: uploadBaselineY)
                    
                    ForEach(0..<uploadSegments.count, id: \.self) { idx in
                        let seg = uploadSegments[idx]
                        if let first = seg.points.first, let last = seg.points.last {
                            // Upload Area Fill
                            Path { path in
                                path.move(to: CGPoint(x: first.x, y: uploadBaselineY))
                                for pt in seg.points {
                                    path.addLine(to: pt)
                                }
                                path.addLine(to: CGPoint(x: last.x, y: uploadBaselineY))
                                path.closeSubpath()
                            }
                            .fill(
                                LinearGradient(
                                    colors: [uploadColor.opacity(0.38), uploadColor.opacity(0.04)],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                            
                            // Upload Stroke Line
                            Path { path in
                                if seg.points.count == 1 {
                                    path.move(to: CGPoint(x: first.x, y: uploadBaselineY))
                                    path.addLine(to: first)
                                } else {
                                    path.move(to: first)
                                    for pt in seg.points.dropFirst() {
                                        path.addLine(to: pt)
                                    }
                                }
                            }
                            .stroke(
                                uploadColor.opacity(0.95),
                                style: StrokeStyle(lineWidth: 1.25, lineCap: .round, lineJoin: .round)
                            )
                        }
                    }
                }
                
                // Download graph (Bottom half: needle spikes growing DOWN from midY)
                if !visibleDownload.isEmpty {
                    let downloadBaselineY = midY + 0.75
                    let downloadPoints = calculatePoints(
                        data: visibleDownload,
                        in: size,
                        baselineY: downloadBaselineY,
                        heightAvailable: midY - 6.0,
                        isUpward: false
                    )
                    let downloadSegments = extractSegments(points: downloadPoints, values: visibleDownload, baselineY: downloadBaselineY)
                    
                    ForEach(0..<downloadSegments.count, id: \.self) { idx in
                        let seg = downloadSegments[idx]
                        if let first = seg.points.first, let last = seg.points.last {
                            // Download Area Fill
                            Path { path in
                                path.move(to: CGPoint(x: first.x, y: downloadBaselineY))
                                for pt in seg.points {
                                    path.addLine(to: pt)
                                }
                                path.addLine(to: CGPoint(x: last.x, y: downloadBaselineY))
                                path.closeSubpath()
                            }
                            .fill(
                                LinearGradient(
                                    colors: [downloadColor.opacity(0.04), downloadColor.opacity(0.38)],
                                    startPoint: .center,
                                    endPoint: .bottom
                                )
                            )
                            
                            // Download Stroke Line
                            Path { path in
                                if seg.points.count == 1 {
                                    path.move(to: CGPoint(x: first.x, y: downloadBaselineY))
                                    path.addLine(to: first)
                                } else {
                                    path.move(to: first)
                                    for pt in seg.points.dropFirst() {
                                        path.addLine(to: pt)
                                    }
                                }
                            }
                            .stroke(
                                downloadColor.opacity(0.95),
                                style: StrokeStyle(lineWidth: 1.25, lineCap: .round, lineJoin: .round)
                            )
                        }
                    }
                }
                
                // Peak transfer rate annotations in top-left and bottom-left (matching Stats)
                VStack(alignment: .leading) {
                    Text(TuckedFormatter.formatPanelRate(peakUpload))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.85))
                        .padding(.leading, 8)
                        .padding(.top, 4)
                    
                    Spacer()
                    
                    Text(TuckedFormatter.formatPanelRate(peakDownload))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.85))
                        .padding(.leading, 8)
                        .padding(.bottom, 4)
                }
                .allowsHitTesting(false)
            }
        }
        .frame(height: 60)
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
        let effectiveCapacity = max(capacity, 2)
        let usableWidth = size.width - 8.0
        let slotWidth = usableWidth / CGFloat(effectiveCapacity - 1)
        let rightEdgeX = size.width - 4.0
        
        let count = data.count
        let startX = rightEdgeX - CGFloat(count - 1) * slotWidth
        
        return data.enumerated().map { index, value in
            let x = startX + CGFloat(index) * slotWidth
            let normalized = CGFloat(max(0.0, min(1.0, value / maxVal)))
            let delta = normalized * heightAvailable
            let y = isUpward ? (baselineY - delta) : (baselineY + delta)
            return CGPoint(x: x, y: y)
        }
    }
    
    private func extractSegments(points: [CGPoint], values: [Double], baselineY: CGFloat) -> [SparklineSegment] {
        guard points.count == values.count, !points.isEmpty else { return [] }
        
        var segments: [SparklineSegment] = []
        var currentIndices: [Int] = []
        
        for i in 0..<values.count {
            if values[i] > 0 {
                // If starting a new active burst, anchor previous 0 sample to baseline if available
                if currentIndices.isEmpty && i > 0 {
                    currentIndices.append(i - 1)
                }
                currentIndices.append(i)
            } else {
                if !currentIndices.isEmpty {
                    // Include this 0 sample to anchor the end of the burst to baseline
                    currentIndices.append(i)
                    let segmentPoints = currentIndices.map { points[$0] }
                    segments.append(SparklineSegment(points: segmentPoints))
                    currentIndices.removeAll()
                }
            }
        }
        
        if !currentIndices.isEmpty {
            let segmentPoints = currentIndices.map { points[$0] }
            segments.append(SparklineSegment(points: segmentPoints))
        }
        
        return segments
    }
}
