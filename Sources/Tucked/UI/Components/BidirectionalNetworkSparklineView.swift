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

            let midY = alignStroke(size.height / 2.0)
            let topQuarterY = alignStroke(midY / 2.0)
            let bottomQuarterY = alignStroke(midY + (size.height - midY) / 2.0)

            // 25% and 75% subtle graticule guidelines
            let guideStyle = StrokeStyle(lineWidth: pixel, lineCap: .square, dash: [pixel, pixel * 3])

            var topQuarterPath = Path()
            topQuarterPath.move(to: CGPoint(x: 0, y: topQuarterY))
            topQuarterPath.addLine(to: CGPoint(x: size.width, y: topQuarterY))
            context.stroke(topQuarterPath, with: .color(Color.primary.opacity(0.05)), style: guideStyle)

            var bottomQuarterPath = Path()
            bottomQuarterPath.move(to: CGPoint(x: 0, y: bottomQuarterY))
            bottomQuarterPath.addLine(to: CGPoint(x: size.width, y: bottomQuarterY))
            context.stroke(bottomQuarterPath, with: .color(Color.primary.opacity(0.05)), style: guideStyle)

            let effectiveCapacity = max(capacity, 2)
            let visibleUpload = Array(uploadData.suffix(effectiveCapacity))
            let visibleDownload = Array(downloadData.suffix(effectiveCapacity))
            let totalSlots = CGFloat(effectiveCapacity - 1)
            let stepX = size.width / totalSlots
            let heightAvailable = max(midY - (3.0 * pixel), 1.0)

            // Render Upload (Top half: needle spikes growing UP from midY)
            if !visibleUpload.isEmpty {
                let uploadCeiling = Self.steppedCeiling(for: visibleUpload.max() ?? 0.0)
                let startX = max(0, size.width - CGFloat(visibleUpload.count - 1) * stepX)

                var points = [CGPoint]()
                points.reserveCapacity(visibleUpload.count)

                for (index, value) in visibleUpload.enumerated() {
                    let rawX = startX + CGFloat(index) * stepX
                    let normalized = CGFloat(max(0.0, min(1.0, value / uploadCeiling)))
                    let rawY = midY - (normalized * heightAvailable)
                    points.append(CGPoint(x: snapCoord(rawX), y: snapCoord(rawY)))
                }

                var uploadPath = Path()
                if visibleUpload.count == 1 {
                    let rawY = midY - (CGFloat(max(0.0, min(1.0, visibleUpload[0] / uploadCeiling))) * heightAvailable)
                    let y = alignStroke(rawY)
                    uploadPath.move(to: CGPoint(x: startX, y: y))
                    uploadPath.addLine(to: CGPoint(x: size.width, y: y))
                } else if let first = points.first {
                    uploadPath.move(to: first)
                    for pt in points.dropFirst() {
                        uploadPath.addLine(to: pt)
                    }
                }

                let uploadStyle = StrokeStyle(
                    lineWidth: pixel,
                    lineCap: .butt,
                    lineJoin: .miter,
                    miterLimit: 10.0
                )
                context.stroke(uploadPath, with: .color(uploadColor), style: uploadStyle)
            }

            // Render Download (Bottom half: needle spikes growing DOWN from midY)
            if !visibleDownload.isEmpty {
                let downloadCeiling = Self.steppedCeiling(for: visibleDownload.max() ?? 0.0)
                let startX = max(0, size.width - CGFloat(visibleDownload.count - 1) * stepX)

                var points = [CGPoint]()
                points.reserveCapacity(visibleDownload.count)

                for (index, value) in visibleDownload.enumerated() {
                    let rawX = startX + CGFloat(index) * stepX
                    let normalized = CGFloat(max(0.0, min(1.0, value / downloadCeiling)))
                    let rawY = midY + (normalized * heightAvailable)
                    points.append(CGPoint(x: snapCoord(rawX), y: snapCoord(rawY)))
                }

                var downloadPath = Path()
                if visibleDownload.count == 1 {
                    let rawY = midY + (CGFloat(max(0.0, min(1.0, visibleDownload[0] / downloadCeiling))) * heightAvailable)
                    let y = alignStroke(rawY)
                    downloadPath.move(to: CGPoint(x: startX, y: y))
                    downloadPath.addLine(to: CGPoint(x: size.width, y: y))
                } else if let first = points.first {
                    downloadPath.move(to: first)
                    for pt in points.dropFirst() {
                        downloadPath.addLine(to: pt)
                    }
                }

                let downloadStyle = StrokeStyle(
                    lineWidth: pixel,
                    lineCap: .butt,
                    lineJoin: .miter,
                    miterLimit: 10.0
                )
                context.stroke(downloadPath, with: .color(downloadColor), style: downloadStyle)
            }

            // Center datum line dividing upload and download (drawn on top to maintain crisp neutral zero axis)
            var centerLinePath = Path()
            centerLinePath.move(to: CGPoint(x: 0, y: midY))
            centerLinePath.addLine(to: CGPoint(x: size.width, y: midY))
            context.stroke(
                centerLinePath,
                with: .color(Color.primary.opacity(0.18)),
                style: StrokeStyle(lineWidth: pixel, lineCap: .butt)
            )
        }
        .frame(height: 52)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(0.03))
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.15))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private static func steppedCeiling(for peak: Double) -> Double {
        let thresholds: [Double] = [
            128 * 1024,        // 128 KB/s
            512 * 1024,        // 512 KB/s
            2 * 1024 * 1024,   // 2 MB/s
            10 * 1024 * 1024,  // 10 MB/s
            50 * 1024 * 1024,  // 50 MB/s
            100 * 1024 * 1024  // 100 MB/s
        ]
        for threshold in thresholds {
            if peak <= threshold {
                return threshold
            }
        }
        return max(peak, 100 * 1024 * 1024)
    }
}

