import SwiftUI

/// Root container view for the single shelf surface.
public struct ShelfView: View {
    @ObservedObject public var model: ShelfModel
    
    public init(model: ShelfModel) {
        self.model = model
    }
    
    public var body: some View {
        Group {
            switch model.currentRoute {
            case .overview:
                OverviewView(model: model)
            case .settings:
                SettingsView(model: model)
            }
        }
        .background(.ultraThinMaterial)
    }
}
