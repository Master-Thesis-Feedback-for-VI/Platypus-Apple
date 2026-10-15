import SwiftUI
import UIKit

/// Opaque surfaces keep contrast predictable, including over live camera images.
enum AppTheme {
    static let background = Color.black
    static let text = Color.yellow
    static let secondaryText = Color.white
    static let error = Color(red: 1, green: 0.55, blue: 0.55)

    static func configureAppearance() {
        let navigation = UINavigationBarAppearance()
        navigation.configureWithOpaqueBackground()
        navigation.backgroundColor = .black
        navigation.titleTextAttributes = [.foregroundColor: UIColor.yellow]
        navigation.largeTitleTextAttributes = [.foregroundColor: UIColor.yellow]
        UINavigationBar.appearance().standardAppearance = navigation
        UINavigationBar.appearance().scrollEdgeAppearance = navigation
        UINavigationBar.appearance().compactAppearance = navigation

        let tabs = UITabBarAppearance()
        tabs.configureWithOpaqueBackground()
        tabs.backgroundColor = .black
        for item in [tabs.stackedLayoutAppearance, tabs.inlineLayoutAppearance,
                     tabs.compactInlineLayoutAppearance] {
            item.normal.iconColor = .white
            item.normal.titleTextAttributes = [.foregroundColor: UIColor.white]
            item.selected.iconColor = .yellow
            item.selected.titleTextAttributes = [.foregroundColor: UIColor.yellow]
        }
        UITabBar.appearance().standardAppearance = tabs
        UITabBar.appearance().scrollEdgeAppearance = tabs
    }
}

struct HighContrastButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var isToolbarButton = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(AppTheme.text)
            .padding(.horizontal, isToolbarButton ? 20 : 12)
            .padding(.vertical, isToolbarButton ? 12 : 8)
            .frame(minWidth: isToolbarButton ? 52 : 44, minHeight: isToolbarButton ? 52 : 44)
            .background(
                configuration.isPressed ? Color(white: 0.2) : AppTheme.background,
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        AppTheme.text,
                        style: StrokeStyle(lineWidth: isToolbarButton ? 3 : 2, dash: isEnabled ? [] : [5, 3])
                    )
                    .allowsHitTesting(false)
            }
    }
}

extension View {
    func highContrastTheme() -> some View {
        self
            .preferredColorScheme(.dark)
            // Start larger, but never reduce a user's accessibility text size.
            .dynamicTypeSize(.xxLarge ... .accessibility5)
            .font(.body)
            .foregroundStyle(AppTheme.text)
            .tint(AppTheme.text)
            .buttonStyle(HighContrastButtonStyle())
            .background(AppTheme.background.ignoresSafeArea())
    }

    func highContrastForm() -> some View {
        self
            // Navigation rows retain their native full-row interaction and chevrons.
            .buttonStyle(.automatic)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 60)
            .background(AppTheme.background)
    }
}
