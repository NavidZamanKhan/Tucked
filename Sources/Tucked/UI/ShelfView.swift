import SwiftUI

/// Root container view for the single shelf surface.
public struct ShelfView: View {
    @ObservedObject public var model: ShelfModel
    
    public init(model: ShelfModel) {
        self.model = model
    }
    
    private var backgroundColor: Color {
        if model.isEffectiveDark {
            return Color(red: 0.08, green: 0.08, blue: 0.09)
        } else {
            return Color(red: 0.96, green: 0.96, blue: 0.97)
        }
    }
    
    public var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()
            
            Group {
                switch model.currentRoute {
                case .overview:
                    OverviewView(model: model)
                case .settings:
                    SettingsView(model: model)
                }
            }
        }
        .preferredColorScheme(model.preferredColorScheme)
    }
}
