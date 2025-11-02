import SwiftUI

struct AppInfoView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    private var backgroundColor: Color {
        Color.black
    }
    
    private var textColor: Color {
        Color.amberAccent
    }
    
    private var secondaryTextColor: Color {
        Color.amberAccentMuted
    }
    
    // MARK: - Constants
    private enum Strings {
        static let appName: LocalizedStringKey = "app_info.app_name"
        static let tagline: LocalizedStringKey = "app_info.tagline"

        enum About {
            static let title: LocalizedStringKey = "app_info.about.title"
            static let description: LocalizedStringKey = "app_info.about.description"
        }
    }
    
    var body: some View {
        #if os(macOS)
        VStack(spacing: 0) {
            // Custom header for macOS
            HStack {
                Spacer()
                Button("app_info.done") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(textColor)
                .padding()
            }
            .background(backgroundColor.opacity(0.95))
            
            ScrollView {
                infoContent
            }
            .background(backgroundColor)
        }
        .frame(width: 600, height: 700)
        #else
        NavigationView {
            ScrollView {
                infoContent
            }
            .background(backgroundColor)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.bitchatSystem(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(textColor)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("app_info.close")
                }
            }
        }
        #endif
    }
    
    @ViewBuilder
    private var infoContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            VStack(alignment: .center, spacing: 8) {
                Text(Strings.appName)
                    .font(.bitchatSystem(size: 32, weight: .bold, design: .monospaced))
                    .foregroundColor(textColor)
                
                Text(Strings.tagline)
                    .font(.bitchatSystem(size: 16, design: .monospaced))
                    .foregroundColor(secondaryTextColor)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical)
            
            // About Section
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(Strings.About.title)
                
                Text(Strings.About.description)
                    .font(.bitchatSystem(size: 14, design: .monospaced))
                    .foregroundColor(textColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            .padding(.top)
        }
        .padding()
    }
}

struct SectionHeader: View {
    let title: LocalizedStringKey
    @Environment(\.colorScheme) var colorScheme
    
    private var textColor: Color {
        Color.amberAccent
    }
    
    init(_ title: LocalizedStringKey) {
        self.title = title
    }
    
    var body: some View {
        Text(title)
            .font(.bitchatSystem(size: 16, weight: .bold, design: .monospaced))
            .foregroundColor(textColor)
            .padding(.top, 8)
    }
}

#Preview("Default") {
    AppInfoView()
}

#Preview("Dynamic Type XXL") {
    AppInfoView()
        .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
}

#Preview("Dynamic Type XS") {
    AppInfoView()
        .environment(\.sizeCategory, .extraSmall)
}
