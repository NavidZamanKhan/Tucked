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
            let topInset: CGFloat = 2.0 * pixel
            let usableHalfHeight = max(midY - topInset, 1.0)

            let effectiveCapacity = max(capacity, 2)
            let visibleUpload = Array(uploadData.suffix(effectiveCapacity))
            let visibleDownload = Array(downloadData.suffix(effectiveCapacity))
            let maxSamples = max(visibleUpload.count, visibleDownload.count)
            guard maxSamples > 0 else { return }

            let stepX = size.width / CGFloat(effectiveCapacity - 1)
            let strokeStyle = StrokeStyle(lineWidth: pixel, lineCap: .round, lineJoin: .round)

            let hasDownload = visibleDownload.contains(where: { $0 > 0 })
            let hasUpload = visibleUpload.contains(where: { $0 > 0 })

            // Render Download (pointing UP from midY)
            if visibleDownload.count >= 2 && hasDownload {
                let downloadCeiling = Self.steppedCeiling(for: visibleDownload.max() ?? 0.0)
                let startX = max(0, size.width - CGFloat(visibleDownload.count - 1) * stepX)

                var rxPoints: [CGPoint] = []
                rxPoints.reserveCapacity(visibleDownload.count)

                for (index, value) in visibleDownload.enumerated() {
                    let rawX = startX + CGFloat(index) * stepX
                    let alignedX = floor(rawX * scale) * pixel
                    let normalized = CGFloat(max(0.0, min(1.0, value / downloadCeiling)))
                    let rawY = midY - (normalized * usableHalfHeight)
                    let alignedY = floor(rawY * scale + 0.5) * pixel
                    rxPoints.append(CGPoint(x: alignedX, y: alignedY))
                }

                // Download Area Fill
                var rxArea = Path()
                rxArea.move(to: CGPoint(x: rxPoints[0].x, y: midY))
                rxArea.addLine(to: rxPoints[0])
                for i in 1..<rxPoints.count {
                    rxArea.addLine(to: rxPoints[i])
                }
                rxArea.addLine(to: CGPoint(x: rxPoints[rxPoints.count - 1].x, y: midY))
                rxArea.closeSubpath()

                let rxShading = GraphicsContext.Shading.linearGradient(
                    Gradient(colors: [
                        downloadColor.opacity(0.35),
                        downloadColor.opacity(0.08)
                    ]),
                    startPoint: CGPoint(x: 0, y: midY - usableHalfHeight),
                    endPoint: CGPoint(x: 0, y: midY)
                )
                context.fill(rxArea, with: rxShading)

                // Download Hairline Stroke (strokes active bursts and transitions)
                var rxStroke = Path()
                for i in 1..<rxPoints.count {
                    if visibleDownload[i] > 0 || visibleDownload[i - 1] > 0 {
                        rxStroke.move(to: rxPoints[i - 1])
                        rxStroke.addLine(to: rxPoints[i])
                    }
                }
                context.stroke(rxStroke, with: .color(downloadColor.opacity(0.95)), style: strokeStyle)
            }

            // Render Upload (pointing DOWN from midY)
            if visibleUpload.count >= 2 && hasUpload {
                let uploadCeiling = Self.steppedCeiling(for: visibleUpload.max() ?? 0.0)
                let startX = max(0, size.width - CGFloat(visibleUpload.count - 1) * stepX)

                var txPoints: [CGPoint] = []
                txPoints.reserveCapacity(visibleUpload.count)

                for (index, value) in visibleUpload.enumerated() {
                    let rawX = startX + CGFloat(index) * stepX
                    let alignedX = floor(rawX * scale) * pixel
                    let normalized = CGFloat(max(0.0, min(1.0, value / uploadCeiling)))
                    let rawY = midY + (normalized * usableHalfHeight)
                    let alignedY = floor(rawY * scale + 0.5) * pixel
                    txPoints.append(CGPoint(x: alignedX, y: alignedY))
                }

                // Upload Area Fill
                var txArea = Path()
                txArea.move(to: CGPoint(x: txPoints[0].x, y: midY))
                txArea.addLine(to: txPoints[0])
                for i in 1..<txPoints.count {
                    txArea.addLine(to: txPoints[i])
                }
                txArea.addLine(to: CGPoint(x: txPoints[txPoints.count - 1].x, y: midY))
                txArea.closeSubpath()

                let txShading = GraphicsContext.Shading.linearGradient(
                    Gradient(colors: [
                        uploadColor.opacity(0.08),
                        uploadColor.opacity(0.35)
                    ]),
                    startPoint: CGPoint(x: 0, y: midY),
                    endPoint: CGPoint(x: 0, y: midY + usableHalfHeight)
                )
                context.fill(txArea, with: txShading)

                // Upload Hairline Stroke (strokes active bursts and transitions)
                var txStroke = Path()
                for i in 1..<txPoints.count {
                    if visibleUpload[i] > 0 || visibleUpload[i - 1] > 0 {
                        txStroke.move(to: txPoints[i - 1])
                        txStroke.addLine(to: txPoints[i])
                    }
                }
                context.stroke(txStroke, with: .color(uploadColor.opacity(0.95)), style: strokeStyle)
            }

            // Crisp Datum Center Line (drawn on top to guarantee a clean neutral boundary)
            var centerLinePath = Path()
            centerLinePath.move(to: CGPoint(x: 0, y: strokeMidY))
            centerLinePath.addLine(to: CGPoint(x: size.width, y: strokeMidY))
            context.stroke(
                centerLinePath,
                with: .color(Color(white: 0.32)),
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

