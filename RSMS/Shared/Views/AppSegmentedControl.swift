import SwiftUI

public struct AppSegmentedOption<Selection: Hashable>: Identifiable {
    public let id: Selection
    public let title: String
    public let badge: String?

    public init(id: Selection, title: String, badge: String? = nil) {
        self.id = id
        self.title = title
        self.badge = badge
    }
}

public struct AppSegmentedControl<Selection: Hashable>: View {
    public let options: [AppSegmentedOption<Selection>]
    @Binding public var selection: Selection

    @Namespace private var selectionNamespace

    public init(
        options: [AppSegmentedOption<Selection>],
        selection: Binding<Selection>
    ) {
        self.options = options
        self._selection = selection
    }

    public var body: some View {
        HStack(spacing: 8) {
            ForEach(options) { option in
                let isSelected = selection == option.id

                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                        selection = option.id
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(LocalizedStringKey(option.title))
                            .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        if let badge = option.badge {
                            Text(badge)
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(isSelected ? Color.white.opacity(0.22) : CatalogTheme.surface)
                                .clipShape(Capsule())
                        }
                    }
                    .foregroundColor(isSelected ? .white : CatalogTheme.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 7) // Reduced from 9
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 12, style: .continuous) // Reduced from 14
                                .fill(
                                    LinearGradient(
                                        colors: [CatalogTheme.deepAccent, CatalogTheme.primary],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .matchedGeometryEffect(id: "app-segment-highlight", in: selectionNamespace)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4) // Reduced from 5
        .background(Color.white.opacity(0.88))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous) // Reduced from 18
                .stroke(CatalogTheme.divider, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
    }
}
