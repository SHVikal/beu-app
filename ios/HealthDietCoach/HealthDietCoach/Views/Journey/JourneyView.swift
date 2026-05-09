import SwiftUI

struct JourneyView: View {
    let snapshot: JourneySnapshot?
    let challenges: [JourneyChallenge]
    let selectedChallenge: JourneyChallenge
    let isHealthConnected: Bool
    let onSelectChallenge: (JourneyChallenge) -> Void
    let onSyncHealth: () -> Void

    @State private var showingRouteSelector = false
    @State private var pendingChallenge: JourneyChallenge?
    @State private var showingSwitchConfirmation = false
    @State private var showingBadges = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                JourneyHeaderView(onOpenRoutes: { showingRouteSelector = true }, onOpenRewards: { showingBadges = true })

                JourneyRouteSelectorView(
                    challenge: selectedChallenge,
                    onTap: { showingRouteSelector = true }
                )

                if isHealthConnected == false {
                    disconnectedState
                } else if let snapshot {
                    JourneyHeroCard(snapshot: snapshot)
                    JourneyCityCardsCarousel(snapshot: snapshot)
                    JourneyStatsSection(snapshot: snapshot)
                    JourneyRewardsCard(snapshot: snapshot)
                    JourneyUnlockablesSection(
                        snapshot: snapshot,
                        onOpenBadges: { showingBadges = true }
                    )
                    JourneyDailyMissionCard(mission: snapshot.mission)
                    JourneyBadgesPreviewSection(
                        achievements: snapshot.achievements,
                        onOpenAll: { showingBadges = true }
                    )
                } else {
                    emptyState
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 150)
        }
        .background(BeUTheme.background.ignoresSafeArea())
        .sheet(isPresented: $showingRouteSelector) {
            JourneyRouteSelectorSheet(
                challenges: challenges,
                selectedChallenge: selectedChallenge,
                onSelect: { challenge in
                    if challenge.id == selectedChallenge.id {
                        showingRouteSelector = false
                    } else {
                        pendingChallenge = challenge
                        showingRouteSelector = false
                        showingSwitchConfirmation = true
                    }
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingBadges) {
            if let snapshot {
                JourneyBadgesView(achievements: snapshot.achievements)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .confirmationDialog(
            "Switch journey?",
            isPresented: $showingSwitchConfirmation,
            titleVisibility: .visible
        ) {
            Button("Switch to \(pendingChallenge?.title ?? "journey")") {
                guard let pendingChallenge else { return }
                onSelectChallenge(pendingChallenge)
                self.pendingChallenge = nil
            }
            Button("Cancel", role: .cancel) {
                pendingChallenge = nil
            }
        } message: {
            Text("Your progress is stored separately for each route. Switching now will keep your current route history intact.")
        }
    }

    private var disconnectedState: some View {
        BeUCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Connect Apple Health to start your journey.")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(BeUTheme.primaryText)
                Text("BeU uses your Apple Health steps to move you across each route. Sync once, then your Travel Trail keeps updating in the background.")
                    .font(BeUTheme.bodyFont)
                    .foregroundColor(BeUTheme.secondaryText)
                Button("Sync Health", action: onSyncHealth)
                    .buttonStyle(BeUPrimaryButtonStyle())
            }
        }
    }

    private var emptyState: some View {
        BeUCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("No steps synced yet today.")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(BeUTheme.primaryText)
                Text("Your route is ready. Sync Apple Health and take a few steps to start moving toward \(selectedChallenge.destinationCity).")
                    .font(BeUTheme.bodyFont)
                    .foregroundColor(BeUTheme.secondaryText)
                Button("Sync Health", action: onSyncHealth)
                    .buttonStyle(BeUSecondaryButtonStyle())
            }
        }
    }
}

