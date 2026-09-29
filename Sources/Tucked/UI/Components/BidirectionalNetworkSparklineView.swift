import SwiftUI

/// Bidirectional network sparkline displaying upload (pointing up) and download (pointing down) from a center baseline.
public struct BidirectionalNetworkSparklineView: View {
    public let uploadData: [Double?]
    public let downloadData: [Double?]
    public let uploadColor: Color
    public let downloadColor: Color
    public let capacity: Int

    public init(
        uploadData: [Double?],
        downloadData: [Double?],
        uploadColor: Color = .teal,
        downloadColor: Color = .red,
        capacity: Int = 90
    ) {
        self.uploadData = uploadData
        self.downloadData = downloadData
        self.uploadColor = uploadColor
        self.downloadColor = downloadColor
        self.capacity = capacity
    }

    public init(
        uploadData: [Double],
        downloadData: [Double],
        uploadColor: Color = .teal,
        downloadColor: Color = .red,
        capacity: Int = 90
    ) {
        self.uploadData = uploadData.map { Optional($0) }
        self.downloadData = downloadData.map { Optional($0) }
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
            let startX = max(0, size.width - CGFloat(maxSamples - 1) * stepX)
            let strokeStyle = StrokeStyle(lineWidth: pixel, lineCap: .round, lineJoin: .round)

            // Partition Upload into contiguous non-nil segments (pointing UP above center baseline)
            let uploadCeiling = Self.steppedCeiling(for: visibleUpload.compactMap { $0 }.max() ?? 0.0)
            var txSegments: [[(point: CGPoint, value: Double)]] = []
            var currentTx: [(point: CGPoint, value: Double)] = []

            for (index, maybeValue) in visibleUpload.enumerated() {
                guard let value = maybeValue else {
                    if !currentTx.isEmpty {
                        txSegments.append(currentTx)
                        currentTx = []
                    }
                    continue
                }
                let rawX = startX + CGFloat(index) * stepX
                let alignedX = floor(rawX * scale) * pixel
                let normalized = CGFloat(max(0.0, min(1.0, value / uploadCeiling)))
                let rawY = midY - (normalized * usableHalfHeight)
                let alignedY = floor(rawY * scale + 0.5) * pixel
                currentTx.append((point: CGPoint(x: alignedX, y: alignedY), value: value))
            }
            if !currentTx.isEmpty {
                txSegments.append(currentTx)
            }

            let txShading = GraphicsContext.Shading.linearGradient(
                Gradient(colors: [
                    uploadColor.opacity(0.35),
                    uploadColor.opacity(0.08)
                ]),
                startPoint: CGPoint(x: 0, y: midY - usableHalfHeight),
                endPoint: CGPoint(x: 0, y: midY)
            )

            for segment in txSegments {
                if segment.count >= 2 && segment.contains(where: { $0.value > 0 }) {
                    var txArea = Path()
                    txArea.move(to: CGPoint(x: segment[0].point.x, y: midY))
                    txArea.addLine(to: segment[0].point)
                    for item in segment.dropFirst() {
                        txArea.addLine(to: item.point)
                    }
                    txArea.addLine(to: CGPoint(x: segment[segment.count - 1].point.x, y: midY))
                    txArea.closeSubpath()
                    context.fill(txArea, with: txShading)

                    var txStroke = Path()
                    for i in 1..<segment.count {
                        if segment[i].value > 0 || segment[i - 1].value > 0 {
                            txStroke.move(to: segment[i - 1].point)
                            txStroke.addLine(to: segment[i].point)
                        }
                    }
                    context.stroke(txStroke, with: .color(uploadColor.opacity(0.95)), style: strokeStyle)
                } else if segment.count == 1 && segment[0].value > 0 {
                    var singlePath = Path()
                    singlePath.move(to: CGPoint(x: segment[0].point.x, y: midY))
                    singlePath.addLine(to: segment[0].point)
                    context.stroke(singlePath, with: .color(uploadColor.opacity(0.95)), style: strokeStyle)
                }
            }

            // Partition Download into contiguous non-nil segments (pointing DOWN below center baseline)
            let downloadCeiling = Self.steppedCeiling(for: visibleDownload.compactMap { $0 }.max() ?? 0.0)
            var rxSegments: [[(point: CGPoint, value: Double)]] = []
            var currentRx: [(point: CGPoint, value: Double)] = []

            for (index, maybeValue) in visibleDownload.enumerated() {
                guard let value = maybeValue else {
                    if !currentRx.isEmpty {
                        rxSegments.append(currentRx)
                        currentRx = []
                    }
                    continue
                }
                let rawX = startX + CGFloat(index) * stepX
                let alignedX = floor(rawX * scale) * pixel
                let normalized = CGFloat(max(0.0, min(1.0, value / downloadCeiling)))
                let rawY = midY + (normalized * usableHalfHeight)
                let alignedY = floor(rawY * scale + 0.5) * pixel
                currentRx.append((point: CGPoint(x: alignedX, y: alignedY), value: value))
            }
            if !currentRx.isEmpty {
                rxSegments.append(currentRx)
            }

            let rxShading = GraphicsContext.Shading.linearGradient(
                Gradient(colors: [
                    downloadColor.opacity(0.08),
                    downloadColor.opacity(0.35)
                ]),
                startPoint: CGPoint(x: 0, y: midY),
                endPoint: CGPoint(x: 0, y: midY + usableHalfHeight)
            )

            for segment in rxSegments {
                if segment.count >= 2 && segment.contains(where: { $0.value > 0 }) {
                    var rxArea = Path()
                    rxArea.move(to: CGPoint(x: segment[0].point.x, y: midY))
                    rxArea.addLine(to: segment[0].point)
                    for item in segment.dropFirst() {
                        rxArea.addLine(to: item.point)
                    }
                    rxArea.addLine(to: CGPoint(x: segment[segment.count - 1].point.x, y: midY))
                    rxArea.closeSubpath()
                    context.fill(rxArea, with: rxShading)

                    var rxStroke = Path()
                    for i in 1..<segment.count {
                        if segment[i].value > 0 || segment[i - 1].value > 0 {
                            rxStroke.move(to: segment[i - 1].point)
                            rxStroke.addLine(to: segment[i].point)
                        }
                    }
                    context.stroke(rxStroke, with: .color(downloadColor.opacity(0.95)), style: strokeStyle)
                } else if segment.count == 1 && segment[0].value > 0 {
                    var singlePath = Path()
                    singlePath.move(to: CGPoint(x: segment[0].point.x, y: midY))
                    singlePath.addLine(to: segment[0].point)
                    context.stroke(singlePath, with: .color(downloadColor.opacity(0.95)), style: strokeStyle)
                }
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

