//
//  CardView.swift
//  IlluminoteSceneDemo
//
//  Created by Tobias on 12/5/25.
//


// DesignSystem/Components/CardView.swift
import SwiftUI

enum DSSurfaceRole {
    case reading
    case interactive
    case quiet
}

enum AppCoachStorageKey {
    static let home = "coach.home.dismissed"
    static let journal = "coach.journal.dismissed"
    static let insights = "coach.insights.dismissed"
    static let writing = "coach.writing.dismissed"
}

struct CardView<Content: View>: View {
    let backgroundColor: Color
    let content: Content

    init(backgroundColor: Color = DSColor.surfaceElevated, @ViewBuilder content: () -> Content) {
        self.backgroundColor = backgroundColor
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            content
        }
        .padding(DSSpacing.md)
        .background(backgroundColor.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(DSColor.dividerSoft, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 16, x: 0, y: 10)
    }
}

struct AppPanel<Content: View>: View {
    let title: String?
    let subtitle: String?
    let role: DSSurfaceRole
    let highlighted: Bool
    let content: Content

    init(
        title: String? = nil,
        subtitle: String? = nil,
        role: DSSurfaceRole = .interactive,
        highlighted: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.role = role
        self.highlighted = highlighted
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            if title != nil || subtitle != nil {
                VStack(alignment: .leading, spacing: 6) {
                    if let title {
                        Text(title)
                            .font(DSFont.sectionTitle)
                            .foregroundStyle(DSColor.textPrimary)
                            .lineSpacing(1)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let subtitle {
                        Text(subtitle)
                            .font(DSFont.supporting)
                            .foregroundStyle(DSColor.quietText)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            content
        }
        .padding(DSSpacing.lg)
        .appSurfaceStyle(role: role, highlighted: highlighted)
    }
}

struct AppCoachPanel<Content: View>: View {
    let title: String
    let subtitle: String?
    let role: DSSurfaceRole
    let highlighted: Bool
    let onDismiss: (() -> Void)?
    let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        role: DSSurfaceRole = .quiet,
        highlighted: Bool = false,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.role = role
        self.highlighted = highlighted
        self.onDismiss = onDismiss
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            HStack(alignment: .top, spacing: DSSpacing.md) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(DSFont.sectionTitle)
                        .foregroundStyle(DSColor.textPrimary)
                        .lineSpacing(1)
                        .fixedSize(horizontal: false, vertical: true)

                    if let subtitle {
                        Text(subtitle)
                            .font(DSFont.supporting)
                            .foregroundStyle(DSColor.quietText)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let onDismiss {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .appCircleControl()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss helper guidance")
                }
            }

            content
        }
        .padding(DSSpacing.lg)
        .appSurfaceStyle(role: role, highlighted: highlighted)
    }
}

struct AppSectionHeader: View {
    let eyebrow: String?
    let title: String
    let subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let eyebrow {
                Text(eyebrow.uppercased())
                    .font(DSFont.eyebrow)
                    .tracking(0.7)
                    .foregroundStyle(DSColor.quietTextMuted)
            }

            Text(title)
                .font(DSFont.display)
                .foregroundStyle(DSColor.textPrimary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            if let subtitle {
                Text(subtitle)
                    .font(DSFont.supporting)
                    .foregroundStyle(DSColor.quietText)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct AppPageHeader<Accessory: View>: View {
    let title: String
    let eyebrow: String?
    let subtitle: String?
    let accessory: Accessory

    init(
        title: String,
        eyebrow: String? = nil,
        subtitle: String? = nil,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.title = title
        self.eyebrow = eyebrow
        self.subtitle = subtitle
        self.accessory = accessory()
    }

    init(
        title: String,
        eyebrow: String? = nil,
        subtitle: String? = nil
    ) where Accessory == EmptyView {
        self.title = title
        self.eyebrow = eyebrow
        self.subtitle = subtitle
        self.accessory = EmptyView()
    }

    var body: some View {
        HStack(alignment: .top, spacing: DSSpacing.md) {
            AppSectionHeader(
                eyebrow: eyebrow,
                title: title,
                subtitle: subtitle
            )

            Spacer(minLength: DSSpacing.md)

            accessory
        }
    }
}

struct AppPageScrollView<Content: View>: View {
    let spacing: CGFloat
    let horizontalPadding: CGFloat
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    let content: Content

    init(
        spacing: CGFloat = DSSpacing.lg,
        horizontalPadding: CGFloat = DSSpacing.lg,
        topPadding: CGFloat = DSSpacing.md,
        bottomPadding: CGFloat = DSSpacing.xxl,
        @ViewBuilder content: () -> Content
    ) {
        self.spacing = spacing
        self.horizontalPadding = horizontalPadding
        self.topPadding = topPadding
        self.bottomPadding = bottomPadding
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: spacing) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, horizontalPadding)
            .padding(.top, topPadding)
            .padding(.bottom, bottomPadding)
        }
        .scrollIndicators(.hidden)
    }
}

struct AppInfoChip: View {
    let text: String
    var icon: String? = nil
    var emphasized: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
            }
            Text(text)
                .font(DSFont.meta)
                .lineLimit(1)
        }
        .foregroundStyle(emphasized ? DSColor.brandAccent : DSColor.quietText)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(emphasized ? DSColor.brandAccentSoft : DSColor.quietSurface)
        )
        .overlay(
            Capsule()
                .stroke(emphasized ? DSColor.brandAccent.opacity(0.35) : DSColor.dividerSoft, lineWidth: 1)
        )
    }
}

struct CardView_Previews: PreviewProvider {
    static var previews: some View {
        CardView {
            Text("Card Title")
                .font(DSFont.heading2)
                .foregroundColor(DSColor.textPrimary)
            Text("Some descriptive text for the card — this is a card view example.")
                .font(DSFont.body)
                .foregroundColor(DSColor.textSecondary)
        }
        .padding()
    }
}
