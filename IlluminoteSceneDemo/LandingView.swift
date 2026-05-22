import SwiftUI
import SwiftData
import Charts

private struct HomeExamenLaunch: Identifiable {
    let id = UUID()
    let draft: ExamenSessionDraft
    let stage: ExamenStage
}

private struct LandingHomeSummary {
    struct FocusExperience {
        let type: ExperienceType
        let count: Int
        let hours: Double
    }

    static let empty = LandingHomeSummary(
        lastSessionDateText: "--",
        lastDraftDateText: nil,
        topFocusExperience: nil,
        topExperienceHours: []
    )

    let lastSessionDateText: String
    let lastDraftDateText: String?
    let topFocusExperience: FocusExperience?
    let topExperienceHours: [(type: ExperienceType, count: Int, hours: Double)]

    static func make(sessions: [ExamenSession], drafts: [StatementDraft]) -> LandingHomeSummary {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated

        var counts: [ExperienceType: Int] = [:]
        var hours: [ExperienceType: Double] = [:]

        for session in sessions {
            guard let type = session.experienceType else { continue }
            counts[type, default: 0] += 1
            hours[type, default: 0] += session.hours
        }

        let rankedExperiences = counts
            .map { (type: $0.key, count: $0.value, hours: hours[$0.key] ?? 0) }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count {
                    return lhs.hours > rhs.hours
                }
                return lhs.count > rhs.count
            }

        let topExperienceHours = counts
            .map { (type: $0.key, count: $0.value, hours: hours[$0.key] ?? 0) }
            .filter { $0.hours > 0 }
            .sorted { lhs, rhs in
                if lhs.hours == rhs.hours {
                    return lhs.count > rhs.count
                }
                return lhs.hours > rhs.hours
            }

        return LandingHomeSummary(
            lastSessionDateText: sessions.first.map {
                formatter.localizedString(for: $0.date, relativeTo: Date())
            } ?? "--",
            lastDraftDateText: drafts.first.map {
                formatter.localizedString(for: $0.dateModified, relativeTo: Date())
            },
            topFocusExperience: rankedExperiences.first.map {
                FocusExperience(type: $0.type, count: $0.count, hours: $0.hours)
            },
            topExperienceHours: topExperienceHours
        )
    }
}

struct LandingView: View {
    @Environment(AppSettings.self) private var settings
    @Query(sort: \ExamenSession.date, order: .reverse) private var sessions: [ExamenSession]
    @AppStorage("hasSeenLandingBefore") private var hasSeenLandingBefore = false
    
    @Query(sort: \StatementDraft.dateModified, order: .reverse) private var drafts: [StatementDraft]
    
    @State private var activeExamenLaunch: HomeExamenLaunch?
    @State private var showProfile = false
    @State private var showNewNoteTypePicker = false
    @State private var showExamenGuide = false
    @State private var greetingText = "Welcome"
    @State private var homeSummary = LandingHomeSummary.empty
    
    var body: some View {
        NavigationStack {
            ZStack {
                SacredScreenBackground(settings: settings)
                
                AppPageScrollView {
                    AppPageHeader(
                        title: greetingText,
                        eyebrow: "Home",
                        subtitle: homeSubtitle
                    ) {
                        Button {
                            showProfile = true
                        } label: {
                            Image(systemName: "person.crop.circle")
                                .font(.headline)
                                .appCircleControl(emphasized: true)
                        }
                        .accessibilityLabel("Profile")
                    }

                    if sessions.isEmpty {
                        StartHerePanel(onLearnExamen: { showExamenGuide = true })
                    }

                    HomeLaunchPanel(
                        onStartExamen: launchExamen,
                        onCaptureQuickNote: { showNewNoteTypePicker = true }
                    )

                    AppPanel(
                        title: "At a glance",
                        subtitle: "A quiet summary of where reflection is already gathering.",
                        role: .quiet
                    ) {
                        VStack(spacing: DSSpacing.md) {
                            LandingInsightRow(
                                title: sessions.isEmpty ? "Next step" : "Last reflection",
                                value: sessions.isEmpty ? "Start your first Examen" : homeSummary.lastSessionDateText,
                                detail: sessions.isEmpty ? "Your reflections will gather here over time." : "Open Journal when you want to revisit it."
                            )

                            LandingPanelDivider()

                            LandingInsightRow(
                                title: "Writing",
                                value: homeSummary.lastDraftDateText ?? "No draft yet",
                                detail: homeSummary.lastDraftDateText == nil ? "Move a reflection into writing when you are ready." : "Return to Writing when you want to keep shaping it."
                            )

                            if let top = homeSummary.topFocusExperience {
                                LandingPanelDivider()

                                LandingInsightRow(
                                    title: "Focus emerging",
                                    value: top.type.displayName,
                                    detail: "\(top.count) reflection\(top.count == 1 ? "" : "s") have gathered here."
                                )
                            }
                        }
                    }

                    if !sessions.isEmpty {
                        AppPanel(
                            title: "Recent reflections",
                            subtitle: "Return to the moments that are still speaking to you.",
                            role: .quiet
                        ) {
                            VStack(spacing: DSSpacing.sm) {
                                ForEach(Array(sessions.prefix(3).enumerated()), id: \.element.id) { index, session in
                                    LandingHistoryRow(session: session)
                                    if index < min(3, sessions.count) - 1 {
                                        LandingPanelDivider()
                                    }
                                }
                            }
                        }
                    }

                    if AppSettings.featurePolicy.showsHomeApplicationRecordPrompts {
                        NavigationLink {
                            ExperienceHoursBreakdownView()
                        } label: {
                            ExperienceHoursCard(experiences: Array(homeSummary.topExperienceHours.prefix(5)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("Home")
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog(
            "Quick Note",
            isPresented: $showNewNoteTypePicker,
            titleVisibility: .visible
        ) {
            ForEach(ExperienceType.allCases, id: \.self) { type in
                Button(type.displayName) {
                    startQuickNote(type)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Choose the kind of experience you want to capture. You can add the details right away.")
        }
        .fullScreenCover(item: $activeExamenLaunch) { launch in
            ExamenSessionContainer(draft: launch.draft, initialStage: launch.stage)
        }
        .toolbar(settings.isTabBarVisible ? .visible : .hidden, for: .tabBar)
        .sheet(isPresented: $showProfile) {
            NavigationStack {
                ProfileView()
            }
        }
        .sheet(isPresented: $showExamenGuide) {
            NavigationStack {
                ExamenExplainerView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                showExamenGuide = false
                            }
                        }
                    }
            }
        }
        .onAppear {
            if hasSeenLandingBefore {
                greetingText = "Welcome back"
            } else {
                greetingText = "Welcome"
                hasSeenLandingBefore = true
            }
        }
        .task(id: landingSummaryRevision) {
            homeSummary = LandingHomeSummary.make(sessions: sessions, drafts: drafts)
        }
    }

    private var homeSubtitle: String {
        sessions.isEmpty
            ? "Home is where most people begin. Start with a full Examen when you want clarity and pace, or a note when you need to capture a moment before it fades."
            : "Take time for an Examen, or capture a quick note."
    }

    private func launchExamen() {
        activeExamenLaunch = HomeExamenLaunch(
            draft: ExamenSessionDraft(type: .other),
            stage: .selectType
        )
    }

    private func startQuickNote(_ type: ExperienceType) {
        activeExamenLaunch = HomeExamenLaunch(
            draft: ExamenSessionDraft(type: type),
            stage: .details
        )
    }
    
    private var landingSummaryRevision: Int {
        var hasher = Hasher()
        for session in sessions {
            hasher.combine(session.id)
            hasher.combine(session.date)
            hasher.combine(session.experienceType?.rawValue)
            hasher.combine(session.hours)
        }
        for draft in drafts {
            hasher.combine(draft.id)
            hasher.combine(draft.dateModified)
        }
        return hasher.finalize()
    }
}

private struct StartHerePanel: View {
    @AppStorage(AppCoachStorageKey.home) private var isDismissed = false

    let onLearnExamen: () -> Void

    var body: some View {
        Group {
            if !isDismissed {
                AppCoachPanel(
                    title: "Start here",
                    subtitle: "The Examen is the app's most guided way to review your day with honesty, gratitude, and clarity. Home is where you begin when you want that fuller reflective rhythm.",
                    role: .quiet,
                    onDismiss: dismiss
                ) {
                    Button("What is the Examen?") {
                        onLearnExamen()
                    }
                    .buttonStyle(.appQuiet)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
    }

    private func dismiss() {
        withAnimation(AnimationConfig.screenTransition) {
            isDismissed = true
        }
    }
}

private struct LandingPanelDivider: View {
    var body: some View {
        Rectangle()
            .fill(DSColor.dividerSoft)
            .frame(height: 1)
    }
}

private struct LandingInsightRow: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(DSFont.eyebrow)
                .foregroundStyle(DSColor.quietTextMuted)
            Text(value)
                .font(DSFont.sectionTitle)
                .foregroundStyle(DSColor.textPrimary)
            Text(detail)
                .font(DSFont.supporting)
                .foregroundStyle(DSColor.quietText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HomeLaunchPanel: View {
    let onStartExamen: () -> Void
    let onCaptureQuickNote: () -> Void

    var body: some View {
        VStack(spacing: DSSpacing.xl) {
            Text("Slow down and reflect")
                .font(DSFont.supporting)
                .foregroundStyle(DSColor.quietText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 280)

            VStack(spacing: DSSpacing.lg) {
                Button(action: onStartExamen) {
                    Label("Start Examen", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SacredButtonStyle())
                .accessibilityIdentifier("home.startExamen")
                .accessibilityHint("Begins a full reflection.")

                HStack(spacing: DSSpacing.sm) {
                    Rectangle()
                        .fill(DSColor.dividerSoft)
                        .frame(height: 1)

                    Text("or")
                        .font(DSFont.meta.weight(.semibold))
                        .foregroundStyle(DSColor.quietTextMuted)

                    Rectangle()
                        .fill(DSColor.dividerSoft)
                        .frame(height: 1)
                }

                Button(action: onCaptureQuickNote) {
                    Label("Capture a Quick Note", systemImage: "square.and.pencil")
                }
                .buttonStyle(.appSecondary)
                .accessibilityIdentifier("home.quickNote")
                .accessibilityHint("Captures a note without starting a full Examen.")
            }
            .frame(maxWidth: 328)
        }
        .frame(maxWidth: .infinity, minHeight: 272)
        .padding(.horizontal, DSSpacing.lg)
        .padding(.vertical, DSSpacing.xl)
        .appSurfaceStyle(role: .interactive, highlighted: true)
    }
}

private struct LandingHistoryRow: View {
    let session: ExamenSession

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DSSpacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.experienceType?.displayName ?? "Reflection")
                    .font(DSFont.body.weight(.semibold))
                    .foregroundStyle(DSColor.textPrimary)
                Text(session.date.formatted(date: .abbreviated, time: .shortened))
                    .font(DSFont.meta)
                    .foregroundStyle(DSColor.quietText)
            }

            Spacer()

            if session.hours > 0 {
                AppInfoChip(text: "\(session.hours.formattedOneDecimal) hours", icon: "clock")
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DSColor.quietTextMuted)
            }
        }
        .padding(.vertical, 6)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(DSColor.brandAccent)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(DSFont.sectionTitle)
                    .foregroundStyle(DSColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(title)
                    .font(DSFont.meta)
                    .foregroundStyle(DSColor.quietText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DSSpacing.md)
        .appSurfaceStyle(role: .interactive)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

private struct ExperienceHoursCard: View {
    let experiences: [(type: ExperienceType, count: Int, hours: Double)]

    private var maxHours: Double {
        experiences.map(\.hours).max() ?? 0
    }

    private var accessibilitySummary: String {
        guard !experiences.isEmpty else {
            return "Experience Hours. No logged hours yet. Open the hours breakdown to start building totals."
        }

        let topEntries = experiences.prefix(3).map {
            "\($0.type.displayName): \($0.hours.formattedOneDecimal) hours across \($0.count) notes"
        }
        return "Experience Hours. Hours logged in Illuminote. " + topEntries.joined(separator: ". ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Experience Hours")
                        .font(.headline)
                        .foregroundStyle(DSColor.textPrimary)
                    Text("Hours logged in Illuminote")
                        .font(.caption)
                        .foregroundStyle(DSColor.quietText)
                }
                Spacer()
                Label("See Breakdown", systemImage: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DSColor.brandAccent)
            }

            if experiences.isEmpty {
                Text("Add note details with hours to start building your experience totals.")
                    .font(.subheadline)
                    .foregroundStyle(DSColor.quietText)
            } else {
                Chart(experiences, id: \.type) { item in
                    BarMark(
                        x: .value("Hours", item.hours),
                        y: .value("Experience", item.type.displayName)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [DSColor.goldLight.opacity(0.95), DSColor.goldLight.opacity(0.45)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(6)
                }
                .chartXScale(domain: 0...(maxHours == 0 ? 1 : maxHours * 1.15))
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let label = value.as(String.self) {
                                Text(label)
                                    .font(.caption)
                                    .foregroundStyle(DSColor.quietText)
                            }
                        }
                    }
                }
                .frame(height: CGFloat(max(140, experiences.count * 36)))
                .accessibilityHidden(true)

                VStack(spacing: 8) {
                    ForEach(experiences, id: \.type) { experience in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(experience.type.displayName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(DSColor.textPrimary)
                                Text("\(experience.count) note\(experience.count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(DSColor.quietText)
                            }
                            Spacer()
                            Text("\(experience.hours.formattedOneDecimal) hrs")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(DSColor.brandAccent)
                        }
                    }
                }

                HStack {
                    Text("\(experiences.reduce(0) { $0 + $1.hours }, specifier: "%.1f") total hours")
                        .font(.caption)
                        .foregroundStyle(DSColor.quietText)
                    Spacer()
                    Text("\(experiences.reduce(0) { $0 + $1.count }) notes shown")
                        .font(.caption)
                        .foregroundStyle(DSColor.quietText)
                }
            }
        }
        .padding()
        .appSurfaceStyle(role: .quiet, highlighted: false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityHint("Opens the hours breakdown and application experience tools.")
    }
}

private struct ExperienceHoursBreakdownView: View {
    @Environment(AppSettings.self) private var settings
    @Query(sort: \ExamenSession.date, order: .reverse) private var sessions: [ExamenSession]

    private var hourEntries: [(type: ExperienceType, count: Int, hours: Double)] {
        var counts: [ExperienceType: Int] = [:]
        var hours: [ExperienceType: Double] = [:]

        for session in sessions {
            guard let type = session.experienceType?.canonical, session.hours > 0 else { continue }
            counts[type, default: 0] += 1
            hours[type, default: 0] += session.hours
        }

        return counts
            .map { (type: $0.key, count: $0.value, hours: hours[$0.key] ?? 0) }
            .sorted { lhs, rhs in
                if lhs.hours == rhs.hours {
                    return lhs.count > rhs.count
                }
                return lhs.hours > rhs.hours
            }
    }

    private var totalHours: Double {
        hourEntries.reduce(0) { $0 + $1.hours }
    }

    private var totalNotes: Int {
        hourEntries.reduce(0) { $0 + $1.count }
    }

    var body: some View {
        ZStack {
            SacredScreenBackground(settings: settings)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Logged hours in Illuminote")
                            .font(DSFont.heading2)
                            .foregroundStyle(DSColor.textPrimary)

                        Text("This screen adds up the hours attached to your reflection notes. It gives you a clean running total of what you have already captured in Illuminote.")
                            .font(DSFont.body)
                            .foregroundStyle(DSColor.textSecondary)

                        NavigationLink {
                            ExperienceLogView()
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Need application-ready records too?")
                                    .font(DSFont.caption.weight(.semibold))
                                    .foregroundStyle(DSColor.textSecondary)
                                Text("Manage application-ready experiences")
                                    .font(DSFont.body.weight(.semibold))
                                Text("Keep this separate from brainstorming. Build structured records with dates, contacts, highlights, and notes for AMCAS, TMDSAS, AADSAS, CASPA, and similar applications.")
                                    .font(DSFont.caption)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(SacredButtonStyle())
                    }
                    .padding()
                    .sacredCardStyle(highlighted: false)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("At a glance")
                            .font(DSFont.heading2)
                            .foregroundStyle(DSColor.textPrimary)

                        HStack {
                            summaryMetric(title: "Total hours", value: totalHours.formattedOneDecimal)
                            summaryMetric(title: "Notes with hours", value: "\(totalNotes)")
                        }
                    }
                    .padding()
                    .sacredCardStyle(highlighted: !hourEntries.isEmpty)

                    if hourEntries.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("No logged hours yet")
                                .font(DSFont.heading2)
                                .foregroundStyle(DSColor.textPrimary)
                            Text("Add hours to your reflection notes to start building a clear hours summary here.")
                                .font(DSFont.body)
                                .foregroundStyle(DSColor.textSecondary)
                        }
                        .padding()
                        .sacredCardStyle(highlighted: false)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Hours by experience")
                                .font(DSFont.heading2)
                                .foregroundStyle(DSColor.textPrimary)

                            ForEach(hourEntries, id: \.type) { entry in
                                HStack(alignment: .firstTextBaseline, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(entry.type.displayName)
                                            .font(DSFont.body.weight(.semibold))
                                            .foregroundStyle(DSColor.textPrimary)
                                        Text("\(entry.count) note\(entry.count == 1 ? "" : "s") logged")
                                            .font(DSFont.caption)
                                            .foregroundStyle(DSColor.textSecondary)
                                    }
                                    Spacer()
                                    Text("\(entry.hours.formattedOneDecimal) hrs")
                                        .font(DSFont.body.weight(.semibold))
                                        .foregroundStyle(DSColor.brandAccent)
                                }
                                .padding(.vertical, 6)
                            }
                        }
                        .padding()
                        .sacredCardStyle(highlighted: false)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Hours Breakdown")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func summaryMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(DSFont.heading2)
                .foregroundStyle(DSColor.textPrimary)
            Text(title)
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension Double {
    var formattedOneDecimal: String {
        String(format: "%.1f", self)
    }
}

#Preview {
    LandingView()
        .modelContainer(for: ExamenSession.self, inMemory: true)
}
