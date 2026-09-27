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

            let centerPixel = floor((size.height / 2.0) * scale)
            let midY = centerPixel * pixel
            let strokeMidY = (centerPixel + 0.5) * pixel
            let usableHalfHeight = max(midY - (2.0 * pixel), 1.0)

            let effectiveCapacity = max(capacity, 2)
            let visibleUpload = Array(uploadData.suffix(effectiveCapacity))
            let visibleDownload = Array(downloadData.suffix(effectiveCapacity))
            let maxSamples = max(visibleUpload.count, visibleDownload.count)
            guard maxSamples > 0 else { return }

            let totalSlots = CGFloat(effectiveCapacity)
            let slotWidth = size.width / totalSlots
            let strokeStyle = StrokeStyle(lineWidth: pixel, lineCap: .butt)

            // Render Download Bars (pointing UPWARD into top half from midY)
            if !visibleDownload.isEmpty {
                let downloadCeiling = Self.steppedCeiling(for: visibleDownload.max() ?? 0.0)
                let startX = max(0, size.width - CGFloat(visibleDownload.count) * slotWidth)
                var downloadPath = Path()

                for (index, value) in visibleDownload.enumerated() {
                    guard value > 0 else { continue }
                    let rawX = startX + (CGFloat(index) + 0.5) * slotWidth
                    let barX = (floor(rawX * scale) + 0.5) * pixel

                    let normalized = CGFloat(max(0.0, min(1.0, value / downloadCeiling)))
                    let rawHeight = normalized * usableHalfHeight
                    // Minimum 1-pixel tick for active download traffic
                    let barHeight = max(pixel, ceil(rawHeight * scale) * pixel)
                    let barTopY = midY - barHeight

                    downloadPath.move(to: CGPoint(x: barX, y: midY))
                    downloadPath.addLine(to: CGPoint(x: barX, y: barTopY))
                }

                if !downloadPath.isEmpty {
                    context.stroke(downloadPath, with: .color(downloadColor.opacity(0.85)), style: strokeStyle)
                }
            }

            // Render Upload Bars (pointing DOWNWARD into bottom half from midY + pixel)
            if !visibleUpload.isEmpty {
                let uploadCeiling = Self.steppedCeiling(for: visibleUpload.max() ?? 0.0)
                let startX = max(0, size.width - CGFloat(visibleUpload.count) * slotWidth)
                let uploadBaselineY = midY + pixel
                var uploadPath = Path()

                for (index, value) in visibleUpload.enumerated() {
                    guard value > 0 else { continue }
                    let rawX = startX + (CGFloat(index) + 0.5) * slotWidth
                    let barX = (floor(rawX * scale) + 0.5) * pixel

                    let normalized = CGFloat(max(0.0, min(1.0, value / uploadCeiling)))
                    let rawHeight = normalized * usableHalfHeight
                    // Minimum 1-pixel tick for active upload traffic
                    let barHeight = max(pixel, ceil(rawHeight * scale) * pixel)
                    let barBottomY = uploadBaselineY + barHeight

                    uploadPath.move(to: CGPoint(x: barX, y: uploadBaselineY))
                    uploadPath.addLine(to: CGPoint(x: barX, y: barBottomY))
                }

                if !uploadPath.isEmpty {
                    context.stroke(uploadPath, with: .color(uploadColor.opacity(0.85)), style: strokeStyle)
                }
            }

            // Neutral Center Baseline dividing download and upload
            var centerLinePath = Path()
            centerLinePath.move(to: CGPoint(x: 0, y: strokeMidY))
            centerLinePath.addLine(to: CGPoint(x: size.width, y: strokeMidY))
            context.stroke(
                centerLinePath,
                with: .color(Color.primary.opacity(0.24)),
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

