import SwiftUI
import SwiftData
import Charts

enum ExamenRoute: Hashable {
    case examenSession(ExamenSessionDraft, ExamenStage) // Unified route
}

struct LandingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @Query(sort: \ExamenSession.date, order: .reverse) private var sessions: [ExamenSession]
    @AppStorage("hasSeenLandingBefore") private var hasSeenLandingBefore = false
    
    @Query(sort: \StatementDraft.dateModified, order: .reverse) private var drafts: [StatementDraft]
    
    @State private var navPath = NavigationPath()
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var namespace
    
    // Animation State
    @State private var callGlow = false
    
    @State private var showProfile = false
    @State private var didTapExamen = false
    @State private var showNewNoteTypePicker = false
    @State private var greetingText = "Welcome"
    
    var body: some View {
        NavigationStack(path: $navPath) {
            ZStack {
                // Background
                if settings.selectedTheme == .sacredVoid {
                    RadialGradient(
                        gradient: Gradient(colors: [DSColor.nearBlack, DSColor.deepMaroon]),
                        center: .center,
                        startRadius: 50,
                        endRadius: 350
                    )
                    .ignoresSafeArea()
                } else if settings.selectedTheme == .gradient {
                    AnimatedMeshGradientBackground()
                } else {
                     // Fallback/Standard dark theme
                    Color.black.ignoresSafeArea()
                }
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        HStack {
                            Text(greetingText)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundStyle(.white) // Ensure visibility on dark void
                            Spacer()
                            Button {
                                showProfile = true
                            } label: {
                                Image(systemName: "person.circle")
                                    .font(.title)
                                    .foregroundStyle(.white.opacity(0.8))
                                    .accessibilityLabel("Profile")
                            }
                        }
                        .padding(.top)
                    
                    // Stats Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        StatCard(title: "Total Sessions", value: "\(sessions.count)", icon: "circle.grid.cross")
                        StatCard(title: "Recent", value: lastSessionDate, icon: "calendar")
                    }
                    
                    // Primary CTA
                    Button {
                        didTapExamen.toggle()
                        let draft = ExamenSessionDraft(type: .other)
                        navPath.append(ExamenRoute.examenSession(draft, .selectType))
                    } label: {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Start Examen")
                                .fontWeight(.semibold)
                        }
                    }
                    .buttonStyle(SacredButtonStyle())
                    .sensoryFeedback(.impact(weight: .medium), trigger: didTapExamen)
                    .compat_matchedTransitionSource(id: "startExamen", in: namespace)
                    .padding(.vertical)
                    
                    // Secondary CTA: Quick Note
                    Button {
                        showNewNoteTypePicker = true
                    } label: {
                        Text("New Note")
                            .fontWeight(.medium)
                            .foregroundColor(DSColor.goldLight) // Harmonize with the theme
                            .luminous()
                    }
                    .padding(.bottom)
                    .compat_matchedTransitionSource(id: "newNote", in: namespace)
                    
                    // NEW: Detailed Stats Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        // Card 1: Top Focus
                        if let top = topFocusExperience {
                            StatCard(title: "Top Focus", value: top.type.displayName, icon: "chart.pie.fill")
                        } else {
                            StatCard(title: "Top Focus", value: "--", icon: "chart.pie.fill")
                        }
                        
                        // Card 2: Last Draft Edit
                        StatCard(title: "Last Draft Edit", value: lastDraftDate ?? "No drafts", icon: "doc.text.fill")
                    }

                    NavigationLink {
                        ExperienceHoursBreakdownView()
                    } label: {
                        ExperienceHoursCard(experiences: Array(topExperienceHours.prefix(5)))
                    }
                    .buttonStyle(.plain)


                    // Recent History
                    if !sessions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recent History")
                                .font(.headline)
                                .foregroundStyle(.white.opacity(0.9))
                            
                            ForEach(sessions.prefix(3)) { session in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(session.date.formatted(date: .abbreviated, time: .shortened))
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundStyle(.white)
                                        if let type = session.experienceType {
                                            Text(type.displayName)
                                                .font(.caption)
                                                .foregroundStyle(.white.opacity(0.7))
                                        }
                                    }
                                    Spacer()
                                    if session.hours > 0 {
                                        // Also show hours in history list
                                        Text("\(session.hours, specifier: "%.1f")h")
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.6))
                                            .padding(.trailing, 4)
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                                .padding()
                                .glassCardStyle()
                                .accessibilityElement(children: .combine)
                            }
                        }
                    }
                }
                .padding()
            }
        } // Close ZStack
            .navigationTitle("Dashboard")
            .toolbar(.hidden, for: .navigationBar)
            .confirmationDialog(
                "New Note: Choose Experience Type",
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
                Text("This opens the Session Details form directly without running a full Examen.")
            }
            .navigationDestination(for: ExamenRoute.self) { route in
                switch route {
                case .examenSession(let draft, let stage):
                    ExamenSessionContainer(draft: draft, initialStage: stage)
                        .navigationBarBackButtonHidden(true)
                        // Apply entry transitions from dashboard
                        .compat_zoomTransition(sourceID: stage == .selectType ? "startExamen" : "newNote", in: namespace)
                        .compat_navigationFade()
                        .animation(AnimationConfig.transitionIn, value: navPath)
                }
            }
            .toolbar(settings.isTabBarVisible ? .visible : .hidden, for: .tabBar)
            .sheet(isPresented: $showProfile) {
                NavigationStack {
                    ProfileView()
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
        }
    }

    private func startQuickNote(_ type: ExperienceType) {
        let draft = ExamenSessionDraft(type: type)
        navPath.append(ExamenRoute.examenSession(draft, .details))
    }
    
    private var lastSessionDate: String {
        guard let last = sessions.first else { return "--" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: last.date, relativeTo: Date())
    }
    
    private var lastDraftDate: String? {
        guard let last = drafts.first else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: last.dateModified, relativeTo: Date())
    }
    
    private var topFocusExperience: (type: ExperienceType, count: Int, hours: Double)? {
        var counts: [ExperienceType: Int] = [:]
        var hours: [ExperienceType: Double] = [:]
        
        for session in sessions {
            if let type = session.experienceType {
                counts[type, default: 0] += 1
                hours[type, default: 0] += session.hours
            }
        }
        
        let sorted = counts.map { (type: $0.key, count: $0.value, hours: hours[$0.key] ?? 0) }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count {
                    return lhs.hours > rhs.hours
                }
                return lhs.count > rhs.count
            }

        return sorted.first
    }

    private var topExperienceHours: [(type: ExperienceType, count: Int, hours: Double)] {
        var counts: [ExperienceType: Int] = [:]
        var hours: [ExperienceType: Double] = [:]

        for session in sessions {
            if let type = session.experienceType {
                counts[type, default: 0] += 1
                hours[type, default: 0] += session.hours
            }
        }

        return counts
            .map { (type: $0.key, count: $0.value, hours: hours[$0.key] ?? 0) }
            .filter { $0.hours > 0 }
            .sorted { lhs, rhs in
                if lhs.hours == rhs.hours {
                    return lhs.count > rhs.count
                }
                return lhs.hours > rhs.hours
            }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(DSColor.goldLight) // Gold accent
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .glassCardStyle()
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
                        .foregroundStyle(.white)
                    Text("Hours logged in Illuminote")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                Label("See Breakdown", systemImage: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DSColor.goldLight)
            }

            if experiences.isEmpty {
                Text("Add note details with hours to start building your experience totals.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
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
                                    .foregroundStyle(.white.opacity(0.8))
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
                                    .foregroundStyle(.white)
                                Text("\(experience.count) note\(experience.count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.68))
                            }
                            Spacer()
                            Text("\(experience.hours.formattedOneDecimal) hrs")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(DSColor.goldLight)
                        }
                    }
                }

                HStack {
                    Text("\(experiences.reduce(0) { $0 + $1.hours }, specifier: "%.1f") total hours")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                    Spacer()
                    Text("\(experiences.reduce(0) { $0 + $1.count }) notes shown")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
        }
        .padding()
        .sacredCardStyle(highlighted: !experiences.isEmpty)
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
                                Text("Need application-ready entries too?")
                                    .font(DSFont.caption.weight(.semibold))
                                    .foregroundStyle(DSColor.textSecondary)
                                Text("Manage application experiences")
                                    .font(DSFont.body.weight(.semibold))
                                Text("Build structured records with dates, contacts, highlights, and notes for AMCAS, TMDSAS, AADSAS, CASPA, and similar applications.")
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
                            .foregroundStyle(.white)

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
                                .foregroundStyle(.white)
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
                                .foregroundStyle(.white)

                            ForEach(hourEntries, id: \.type) { entry in
                                HStack(alignment: .firstTextBaseline, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(entry.type.displayName)
                                            .font(DSFont.body.weight(.semibold))
                                            .foregroundStyle(.white)
                                        Text("\(entry.count) note\(entry.count == 1 ? "" : "s") logged")
                                            .font(DSFont.caption)
                                            .foregroundStyle(DSColor.textSecondary)
                                    }
                                    Spacer()
                                    Text("\(entry.hours.formattedOneDecimal) hrs")
                                        .font(DSFont.body.weight(.semibold))
                                        .foregroundStyle(DSColor.goldLight)
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
                .foregroundStyle(.white)
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
