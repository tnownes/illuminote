import SwiftUI
// GridView
struct ExperienceTypeGridView: View {
    let types: [ExperienceType]
    let counts: [ExperienceType: Int]
    var selectedType: ExperienceType?
    var showsHints: Bool = false
    let onTap: (ExperienceType) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var columns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible(), spacing: DSSpacing.sm)]
        }

        return [
            GridItem(.flexible(), spacing: DSSpacing.sm),
            GridItem(.flexible(), spacing: DSSpacing.sm)
        ]
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: DSSpacing.sm) {
            ForEach(types, id: \.self) { type in
                ExperienceTypeTile(type: type,
                                   count: counts[type],
                                   isSelected: selectedType == type,
                                   showsHint: showsHints,
                                   onTap: onTap)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: counts)
        .animation(.easeInOut(duration: 0.18), value: selectedType)
        .padding(DSSpacing.sm)
    }
}

private struct ExperienceTypeTile: View {
    let type: ExperienceType
    let count: Int?
    let isSelected: Bool
    let showsHint: Bool
    let onTap: (ExperienceType) -> Void
    
    private var typeTitle: String {
        type.displayName
    }

    private var iconName: String {
        switch type.canonical {
        case .shadowing: return "eye"
        case .clinical: return "cross.case"
        case .leadership: return "person.2"
        case .research: return "waveform.path.ecg"
        case .work: return "briefcase"
        case .service: return "hands.sparkles"
        case .discernment: return "sparkles"
        case .other: return "sun.max"
        case .volunteer: return "hands.sparkles"
        }
    }

    private var subtitle: String {
        switch type.canonical {
        case .shadowing:
            return "Observed practice"
        case .clinical:
            return "Care encounter"
        case .leadership:
            return "Responsibility"
        case .research:
            return "Curiosity"
        case .work:
            return "Daily work"
        case .service:
            return "Service"
        case .discernment:
            return "Vocation"
        case .other:
            return "Ordinary moment"
        case .volunteer:
            return "Service"
        }
    }
    
    var body: some View {
        Button { onTap(type) } label: {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                Image(systemName: iconName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isSelected ? DSColor.backgroundPrimary : DSColor.brandAccent)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(isSelected ? DSColor.brandAccent : DSColor.brandAccentSoft.opacity(0.55))
                    )
                    .accessibilityHidden(true)

                HStack(alignment: .firstTextBaseline, spacing: DSSpacing.sm) {
                    Text(typeTitle)
                        .font(DSFont.body.weight(.semibold))
                        .foregroundStyle(DSColor.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let count {
                        Text("\(count)")
                            .font(DSFont.meta)
                            .foregroundStyle(DSColor.quietTextMuted)
                    }
                }

                if showsHint {
                    Text(subtitle)
                        .font(DSFont.supporting)
                        .foregroundStyle(DSColor.quietText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.86)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(DSSpacing.md)
            .frame(maxWidth: .infinity, minHeight: showsHint ? 132 : 88, alignment: .leading)
            .appSurfaceStyle(role: .interactive, highlighted: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("examen.type.\(type.rawValue)")
        .accessibilityLabel(typeTitle)
        .accessibilityHint(showsHint ? subtitle : "Choose this experience")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
