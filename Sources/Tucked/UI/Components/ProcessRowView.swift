import SwiftUI

/// Process list row with stable width and hover normal Quit button.
public struct ProcessRowView: View {
    public let item: ProcessItem
    public let formattedMetric: String
    public let onQuit: (ProcessItem) -> Void
    
    @State private var isHovered = false
    
    public init(item: ProcessItem, formattedMetric: String, onQuit: @escaping (ProcessItem) -> Void) {
        self.item = item
        self.formattedMetric = formattedMetric
        self.onQuit = onQuit
    }
    
    public var body: some View {
        HStack(spacing: 6) {
            // Process name
            Text(item.name)
                .font(.system(size: 12))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundColor(.primary)
            
            Spacer()
            
            // Metric value with monospaced digits
            Text(formattedMetric)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundColor(.primary)
            
            // Reserved space for Quit button (16pt wide) so row never shifts
            ZStack {
                if item.isClosable && isHovered {
                    Button(action: {
                        onQuit(item)
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 16, height: 16)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Request normal Quit for \(item.name)")
                    .accessibilityLabel("Quit \(item.name)")
                } else {
                    Color.clear
                        .frame(width: 16, height: 16)
                }
            }
        }
        .frame(height: 20)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
