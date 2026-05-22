//
//  ProfileView.swift
//  IlluminoteSceneDemo
//
//  Created by Nownes, Tobias on 12/1/25.
//

import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \UserProfile.id) private var profiles: [UserProfile]
    // Fetch all sessions to calculate total hours
    @Query private var sessions: [ExamenSession]
    
    @State private var showResetConfirmation = false
    @State private var persistenceAlert: PersistenceAlertContext?
    
    // Computed property to aggregate statistics
    private var experienceStats: [(type: ExperienceType, hours: Double)] {
        var hoursMap: [ExperienceType: Double] = [:]
        
        for session in sessions {
            if let type = session.experienceType {
                hoursMap[type, default: 0] += session.hours
            }
        }
        
        // Return sorted list (most hours first)
        // Explicitly map to expected tuple labels (type, hours)
        let stats = hoursMap.map { (type: $0.key, hours: $0.value) }
        
        return stats.sorted { lhs, rhs in
            lhs.hours > rhs.hours
        }
    }
    
    var body: some View {
        Form {
            if let profile = profiles.first {
                Section(header: Text("Pre-Professional Track")) {
                    Picker("Track", selection: Binding(
                        get: { (profile.preProfessionalTrack ?? .general).canonical },
                        set: { profile.preProfessionalTrack = $0 }
                    )) {
                        ForEach(PreProfessionalTrack.selectableCases, id: \.self) { track in
                            Text(track.displayName).tag(track)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    if profile.preProfessionalTrack == .preMedicine {
                        Picker("Degree Intent", selection: Binding(
                            get: { profile.degreeIntent },
                            set: { profile.degreeIntent = $0 }
                        )) {
                            ForEach(DegreeIntent.allCases) { intent in
                                Text(intent.displayName).tag(intent)
                            }
                        }

                        Toggle("Applying to Texas Schools?", isOn: Binding(
                            get: { profile.isTexasApplicant },
                            set: { profile.isTexasApplicant = $0 }
                        ))

                        if profile.degreeIntent != .doDetail {
                            Toggle("Applying MD-PhD?", isOn: Binding(
                                get: { profile.isMDPhDApplicant },
                                set: { profile.isMDPhDApplicant = $0 }
                            ))
                        }
                    }
                }
                
                Section {
                    Button("Reset Profile", role: .destructive) {
                        showResetConfirmation = true
                    }
                } footer: {
                    Text("Resetting your profile will delete your track selection and show the onboarding screen again. Your journal entries will be preserved.")
                }
                
                // NEW: Experience Statistics Section
                if !experienceStats.isEmpty {
                    Section(header: Text("Experience Statistics")) {
                        ForEach(experienceStats, id: \.type) { stat in
                            HStack {
                                Text(stat.type.displayName)
                                    .foregroundStyle(DSColor.textPrimary)
                                Spacer()
                                Text("\(stat.hours, specifier: "%.1f") hrs")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(DSColor.textSecondary)
                            }
                        }
                    }
                }
            } else {
                ContentUnavailableView("No Profile Found", systemImage: "person.crop.circle.badge.questionmark")
            }
        }
        .navigationTitle("Profile")
        .alert("Reset Profile?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetProfile()
            }
        } message: {
            Text("Are you sure you want to reset your profile? This action cannot be undone.")
        }
        .persistenceFailureAlert($persistenceAlert)
    }
    
    private func resetProfile() {
        if let profile = profiles.first {
            modelContext.delete(profile)
            do {
                try modelContext.persistIfNeeded(for: "reset your profile")
            } catch let error as PersistenceOperationError {
                persistenceAlert = error.alertContext
                return
            } catch {
                persistenceAlert = PersistenceAlertContext.saveFailure(
                    for: "reset your profile",
                    details: error.localizedDescription
                )
                return
            }
            // Dismissing will take us back to Settings, but ContentView will detect no profile and show onboarding
            // We might want to pop to root or let ContentView handle it.
            // Since ContentView observes the query, it should switch to onboarding automatically.
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
            .modelContainer(for: UserProfile.self, inMemory: true)
    }
}
