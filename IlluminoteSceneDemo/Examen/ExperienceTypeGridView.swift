import SwiftUI
// GridView
struct ExperienceTypeGridView: View {
    let types: [ExperienceType]
    let counts: [ExperienceType: Int]
    let onTap: (ExperienceType) -> Void

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: DSSpacing.md),
        GridItem(.flexible(), spacing: DSSpacing.md)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: DSSpacing.md) {
            ForEach(types, id: \.self) { type in
                ExperienceTypeTile(type: type,
                                   count: counts[type],
                                   onTap: onTap)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: counts)
        .padding(DSSpacing.md)
    }
}

private struct ExperienceTypeTile: View {
    let type: ExperienceType
    let count: Int?
    let onTap: (ExperienceType) -> Void
    
    private var typeTitle: String {
        type.displayName
    }
    
    var body: some View {
        Button { onTap(type) } label: {
            VStack(spacing: DSSpacing.xs) {
                Text(typeTitle)
                    .font(DSFont.heading2)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                
                if let count {
                    Text("\(count) entries")
                        .font(DSFont.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(.vertical, DSSpacing.sm)
            .frame(minHeight: 100)
        }
        .buttonStyle(SacredButtonStyle())
    }
}

