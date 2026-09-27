import SwiftUI

/// Root container view for the single shelf surface featuring Dynamic Island morphing physics.
public struct ShelfView: View {
    @ObservedObject public var model: ShelfModel
    
    public init(model: ShelfModel) {
        self.model = model
    }
    
    private var pillBackground: Color {
        if model.isEffectiveDark {
            return Color(red: 0.08, green: 0.08, blue: 0.09).opacity(0.96)
        } else {
            return Color(red: 0.96, green: 0.96, blue: 0.97).opacity(0.96)
        }
    }
    
    private var pillBorderColor: Color {
        if model.isEffectiveDark {
            return Color.white.opacity(0.12)
        } else {
            return Color.black.opacity(0.10)
        }
    }
    
    private var shadowColor: Color {
        if model.isEffectiveDark {
            return Color.black.opacity(0.45)
        } else {
            return Color.black.opacity(0.15)
        }
    }
    
    public var body: some View {
        ZStack(alignment: .top) {
            // Click catcher outside the pill but inside window padding
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    model.requestClose()
                }
            
            // Dynamic Island Floating Pill
            VStack(spacing: 0) {
                Group {
                    switch model.currentRoute {
                    case .overview:
                        OverviewView(model: model)
                    case .settings:
                        SettingsView(model: model)
                    }
                }
                .animation(.easeInOut(duration: 0.22), value: model.currentRoute)
                .opacity(model.isShelfPresented ? 1.0 : 0.0)
                .scaleEffect(
                    model.isShelfPresented ? 1.0 : 0.94,
                    anchor: UnitPoint(x: model.anchorXFraction, y: 0)
                )
            }
            .frame(width: 550)
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(pillBackground)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(pillBorderColor, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: shadowColor, radius: 24, x: 0, y: 12)
            .shadow(color: shadowColor.opacity(0.5), radius: 6, x: 0, y: 2)
            .scaleEffect(
                x: model.isShelfPresented ? 1.0 : 0.35,
                y: model.isShelfPresented ? 1.0 : 0.06,
                anchor: UnitPoint(x: model.anchorXFraction, y: 0)
            )
            .offset(y: model.isShelfPresented ? 6 : -12)
            .opacity(model.isShelfPresented ? 1.0 : 0.0)
        }
        .padding(.horizontal, 30)
        .padding(.top, 0)
        .padding(.bottom, 36)
        .preferredColorScheme(model.preferredColorScheme)
    }
}
