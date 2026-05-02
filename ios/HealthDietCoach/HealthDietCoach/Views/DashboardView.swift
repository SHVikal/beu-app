import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @StateObject private var nutritionViewModel = NutritionViewModel()
    @State private var selectedTab: BeUAppTab = .home

    var body: some View {
        NavigationStack {
            Group {
                if !viewModel.isAuthorized {
                    PermissionView {
                        await viewModel.requestPermissionsAndLoad()
                    }
                } else {
                    dashboardContent
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $nutritionViewModel.showProfileGateway) {
                ProfileGatewayView(
                    nutritionViewModel: nutritionViewModel,
                    onOpenTargets: {
                        nutritionViewModel.showProfileGateway = false
                        nutritionViewModel.showSettings = true
                    }
                )
                .presentationDetents([.large])
            }
            .sheet(isPresented: $nutritionViewModel.showSettings) {
                if let profile = nutritionViewModel.profile {
                    NutritionProfileSettingsView(userId: nutritionViewModel.userId, currentProfile: profile) { updatedProfile in
                        nutritionViewModel.updateProfile(updatedProfile)
                    }
                }
            }
            .sheet(isPresented: $nutritionViewModel.showMealHistory) {
                NavigationStack {
                    MealHistoryView(meals: nutritionViewModel.mealHistory) { meal in
                        nutritionViewModel.deleteMeal(meal)
                    }
                }
            }
            .sheet(isPresented: $nutritionViewModel.showSupplements) {
                SupplementsView(nutritionViewModel: nutritionViewModel)
            }
            .sheet(isPresented: $nutritionViewModel.showHealthHistory) {
                HealthHistoryView(nutritionViewModel: nutritionViewModel)
            }
            .fullScreenCover(isPresented: $nutritionViewModel.showOnboarding) {
                OnboardingView(userId: nutritionViewModel.userId) { profile in
                    nutritionViewModel.completeOnboarding(profile: profile)
                }
            }
            .fullScreenCover(isPresented: $nutritionViewModel.showMealLogging) {
                MealPhotoLoggingFlowView(
                    userId: nutritionViewModel.userId,
                    onSaveMeal: { image, analysis, mealType in
                        nutritionViewModel.saveMealLog(image: image, analysis: analysis, mealType: mealType)
                    },
                    progressProvider: { nutritionViewModel.dailyProgress }
                )
            }
            .overlay(alignment: .center) {
                if viewModel.isLoading {
                    ProgressView("Loading...")
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(BeUTheme.cardBackground)
                        )
                }
            }
            .alert(
                "Health Data Debug",
                isPresented: Binding(
                    get: { viewModel.healthDebugAlertMessage != nil },
                    set: { isPresented in
                        if !isPresented {
                            viewModel.healthDebugAlertMessage = nil
                        }
                    }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.healthDebugAlertMessage ?? "")
            }
            .task {
                nutritionViewModel.loadState()
                syncPersonalizationContext()
            }
            .onChange(of: nutritionViewModel.profile?.id) { _, _ in
                syncPersonalizationContext()
            }
            .onChange(of: nutritionViewModel.caloriesSummaryText) { _, _ in
                syncPersonalizationContext()
            }
            .onChange(of: nutritionViewModel.proteinSummaryText) { _, _ in
                syncPersonalizationContext()
            }
            .onChange(of: nutritionViewModel.supplementService.supplements) { _, _ in
                syncPersonalizationContext()
            }
            .onChange(of: nutritionViewModel.healthHistoryService.conditions) { _, _ in
                syncPersonalizationContext()
            }
        }
        .tint(BeUTheme.primaryText)
    }

    private var dashboardContent: some View {
        ZStack(alignment: .bottom) {
            tabContent
                .background(BeUTheme.background.ignoresSafeArea())

            bottomFade
            BeUTabBar(
                selectedTab: selectedTab,
                onSelect: { tab in
                    selectedTab = tab
                },
                onOpenMeal: openMealLogging
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .home:
            homeTab
        case .plan:
            planTab
        case .progress:
            progressTab
        case .me:
            meTab
        }
    }

    private var homeTab: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                GreetingHeader(
                    dateLabel: currentDateLabel,
                    firstName: greetingFirstName,
                    onBellTap: {
                        Task { await viewModel.runHealthDebugFetch() }
                    },
                    onAvatarTap: openProfile
                )

                HeroReadinessCard(
                    model: viewModel.readinessCard,
                    summary: viewModel.todaySummary
                )

                TodayTargetsCard(plan: currentPlan, meals: nutritionViewModel.todaysMeals)

                ActionPlanOverviewCard(plan: currentPlan) {
                    selectedTab = .plan
                }

                NudgesCard(nudges: Array(currentPlan.realTimeNudges.prefix(2)))

                QuickActionsCard(
                    onLogMeal: openMealLogging,
                    onLogWater: {
                        Task { await viewModel.logWater(0.1) }
                    }
                )

                WeeklySnapshotCard(
                    insights: currentInsights,
                    readinessSummary: viewModel.readinessTrendSummary,
                    consistency: nutritionViewModel.consistencyCard
                ) {
                    selectedTab = .progress
                }

                SyncStatusCard(lines: viewModel.syncDebugLines)
                DebugHealthCard(lines: viewModel.stepDebugSummaryLines) {
                    Task { await viewModel.testStepSync() }
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(BeUTheme.helperFont)
                        .foregroundColor(BeUTheme.lowStatus)
                }

                Text(BeUSafetyCopy.wellnessDisclaimer)
                    .font(BeUTheme.helperFont)
                    .foregroundColor(BeUTheme.mutedText)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 160)
        }
        .refreshable {
            try? await viewModel.refreshData()
            nutritionViewModel.refreshDailyProgress()
        }
    }

    private var planTab: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                tabHeader(kicker: "Action plan", title: "Today")

                BeUCard {
                    VStack(alignment: .leading, spacing: 14) {
                        numberedHeader("01", "Nutrition")
                        HStack(spacing: 12) {
                            planStat(title: "Calories", value: "\(currentPlan.targets.calories)", subtitle: currentPlan.calorieDirection)
                            planStat(title: "Protein", value: "\(currentPlan.targets.proteinGrams)g", subtitle: currentPlan.proteinLevel)
                        }
                        Text("Carb guidance: \(currentPlan.carbGuidance.capitalized)")
                            .font(BeUTheme.bodyFont)
                            .foregroundColor(BeUTheme.secondaryText)
                    }
                }

                BeUCard {
                    VStack(alignment: .leading, spacing: 14) {
                        numberedHeader("02", "Hydration")
                        DashboardTargetBar(
                            value: currentPlan.progress.waterConsumedLiters,
                            target: currentPlan.targets.waterLiters,
                            tint: BeUTheme.accent
                        )
                        Text("Aim for \(String(format: "%.1f", currentPlan.targets.waterLiters))L by evening")
                            .font(BeUTheme.helperFont)
                            .foregroundColor(BeUTheme.secondaryText)
                    }
                }

                BeUCard {
                    VStack(alignment: .leading, spacing: 14) {
                        numberedHeader("03", "Activity")
                        activitySummaryRow(
                            title: currentPlan.targets.strengthTraining.recommendation == .rest ? "Rest day" : "Strength",
                            detail: strengthDescription
                        )
                        activitySummaryRow(
                            title: "Cardio",
                            detail: "\(currentPlan.progress.stepsRemaining) steps remaining · \(currentPlan.targets.cardioMinutes) mins"
                        )
                        DashboardTargetBar(
                            value: Double(currentPlan.progress.stepsCompleted),
                            target: Double(max(currentPlan.targets.steps, 1)),
                            tint: BeUTheme.accent
                        )
                    }
                }

                if !currentPlan.supplementReminders.isEmpty {
                    BeUCard {
                        VStack(alignment: .leading, spacing: 12) {
                            numberedHeader("04", "Supplements")
                            ForEach(currentPlan.supplementReminders, id: \.self) { reminder in
                                reminderRow(text: reminder)
                            }
                        }
                    }
                }

                if let note = currentPlan.healthContextNotes.first {
                    BeUCard {
                        VStack(alignment: .leading, spacing: 12) {
                            numberedHeader("05", "For you")
                            Text(note)
                                .font(BeUTheme.bodyFont)
                                .foregroundColor(BeUTheme.secondaryText)
                                .padding(.leading, 14)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(BeUTheme.accent.opacity(0.08))
                                )
                                .overlay(alignment: .leading) {
                                    Rectangle()
                                        .fill(BeUTheme.accent)
                                        .frame(width: 2)
                                        .padding(.vertical, 10)
                                }
                        }
                    }
                }

                BeUCard {
                    VStack(alignment: .leading, spacing: 12) {
                        numberedHeader("06", "Course correction")
                        if currentPlan.realTimeNudges.isEmpty {
                            Text("You’re on track today. Keep repeating the basics.")
                                .font(BeUTheme.bodyFont)
                                .foregroundColor(BeUTheme.secondaryText)
                        } else {
                            ForEach(currentPlan.realTimeNudges) { nudge in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(nudge.message)
                                        .font(BeUTheme.bodyFont.weight(.semibold))
                                        .foregroundColor(BeUTheme.primaryText)
                                    Text(nudge.reason)
                                        .font(BeUTheme.helperFont)
                                        .foregroundColor(BeUTheme.secondaryText)
                                }
                            }
                        }
                    }
                }

                BeUCard {
                    VStack(alignment: .leading, spacing: 12) {
                        numberedHeader("07", "Why this plan?")
                        ForEach(currentPlan.explanation, id: \.self) { line in
                            Text(line)
                                .font(BeUTheme.bodyFont)
                                .foregroundColor(BeUTheme.secondaryText)
                        }
                    }
                }

                BeUCard {
                    VStack(alignment: .leading, spacing: 10) {
                        KickerText(text: "Safety note")
                        Text(currentPlan.safetyNote)
                            .font(BeUTheme.bodyFont)
                            .foregroundColor(BeUTheme.secondaryText)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 160)
        }
    }

    private var progressTab: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                tabHeader(kicker: "Weekly review", title: "Progress")

                BeUCard {
                    VStack(alignment: .leading, spacing: 16) {
                        KickerText(text: "Readiness trend")
                        ReadinessBars(points: viewModel.readinessTrendSummary.points)
                        HStack {
                            statColumn("Average", value: viewModel.readinessTrendSummary.averageScore.map(String.init) ?? "—")
                            Spacer()
                            statColumn("Trend", value: viewModel.readinessTrendSummary.trendDirection.capitalized)
                        }
                    }
                }

                BeUCard {
                    VStack(alignment: .leading, spacing: 14) {
                        KickerText(text: "Targets vs actuals")
                        DashboardTargetBar(
                            label: "Calories",
                            valueText: "\(nutritionViewModel.weeklySummary?.averageCalories ?? 0)",
                            targetText: "\(currentWeeklyPlan.weeklyTargets.avgDailyCalories)",
                            value: Double(nutritionViewModel.weeklySummary?.averageCalories ?? 0),
                            target: Double(max(currentWeeklyPlan.weeklyTargets.avgDailyCalories, 1)),
                            tint: BeUTheme.accent
                        )
                        DashboardTargetBar(
                            label: "Protein",
                            valueText: "\(Int((nutritionViewModel.weeklySummary?.averageProteinGrams ?? 0).rounded()))g",
                            targetText: "\(currentWeeklyPlan.weeklyTargets.avgDailyProteinGrams)g",
                            value: nutritionViewModel.weeklySummary?.averageProteinGrams ?? 0,
                            target: Double(max(currentWeeklyPlan.weeklyTargets.avgDailyProteinGrams, 1)),
                            tint: BeUTheme.macroFat
                        )
                        DashboardTargetBar(
                            label: "Steps",
                            valueText: "\(averageWeeklySteps)",
                            targetText: "\(currentWeeklyPlan.weeklyTargets.avgDailySteps)",
                            value: Double(averageWeeklySteps),
                            target: Double(max(currentWeeklyPlan.weeklyTargets.avgDailySteps, 1)),
                            tint: BeUTheme.macroCarb
                        )
                    }
                }

                BeUCard {
                    VStack(alignment: .leading, spacing: 8) {
                        KickerText(text: "Consistency")
                        Text("\(currentInsights.consistencyScore)")
                            .font(BeUTheme.bigNumber(size: 48))
                            .monospacedDigit()
                            .foregroundColor(BeUTheme.primaryText)
                        Text(nutritionViewModel.consistencyCard.message)
                            .font(BeUTheme.bodyFont)
                            .foregroundColor(BeUTheme.secondaryText)
                    }
                }

                BeUCard {
                    VStack(alignment: .leading, spacing: 14) {
                        KickerText(text: "What changed")
                        ForEach(currentInsights.cards.prefix(3)) { card in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(card.kicker)
                                    .font(BeUTheme.kickerFont)
                                    .tracking(1.6)
                                    .foregroundColor(BeUTheme.tertiaryText)
                                Text(card.sentence)
                                    .font(BeUTheme.bodyFont)
                                    .foregroundColor(BeUTheme.secondaryText)
                            }
                        }
                    }
                }

                BeUCard {
                    VStack(alignment: .leading, spacing: 14) {
                        KickerText(text: "Try these 3")
                        ForEach(Array(currentInsights.actions.prefix(3).enumerated()), id: \.offset) { index, action in
                            HStack(alignment: .top, spacing: 12) {
                                Circle()
                                    .stroke(BeUTheme.accent, lineWidth: 1.5)
                                    .frame(width: 20, height: 20)
                                    .overlay(
                                        Text("\(index + 1)")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundColor(BeUTheme.accent)
                                    )
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(action.title)
                                        .font(BeUTheme.bodyFont.weight(.semibold))
                                        .foregroundColor(BeUTheme.primaryText)
                                    Text(action.description)
                                        .font(BeUTheme.helperFont)
                                        .foregroundColor(BeUTheme.secondaryText)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 160)
        }
    }

    private var meTab: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                tabHeader(kicker: "Your inputs", title: "Me")

                BeUCard {
                    HStack(spacing: 16) {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [BeUTheme.cardBackground, BeUTheme.accentSoft.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 56)
                            .overlay(
                                Text(String(greetingFirstName.prefix(1)).uppercased())
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundColor(BeUTheme.accent)
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(greetingFirstName)
                                .font(BeUTheme.titleFont)
                                .foregroundColor(BeUTheme.primaryText)
                            Text(goalSegment.title)
                                .font(BeUTheme.helperFont)
                                .foregroundColor(BeUTheme.secondaryText)
                        }

                        Spacer()
                    }
                }

                BeUCard {
                    VStack(alignment: .leading, spacing: 14) {
                        KickerText(text: "Goal")
                        Picker("Goal", selection: Binding(
                            get: { goalSegment },
                            set: { updateGoal($0) }
                        )) {
                            ForEach(MeGoalSegment.allCases) { segment in
                                Text(segment.title).tag(segment)
                            }
                        }
                        .beuSegmentedControlStyle()
                    }
                }

                BeUCard {
                    VStack(spacing: 0) {
                        meRow(title: "Weight", subtitle: weightSummary, action: { nutritionViewModel.showSettings = true })
                        Divider().overlay(BeUTheme.divider)
                        meRow(title: "Height", subtitle: heightSummary, action: { nutritionViewModel.showSettings = true })
                        Divider().overlay(BeUTheme.divider)
                        meRow(title: "Target weight", subtitle: targetWeightSummary, action: { nutritionViewModel.showSettings = true })
                        Divider().overlay(BeUTheme.divider)
                        meRow(title: "Timeline", subtitle: timelineSummary, action: { nutritionViewModel.showSettings = true })
                    }
                }

                BeUCard {
                    VStack(spacing: 0) {
                        meRow(title: "Supplements", subtitle: "\(nutritionViewModel.supplementService.supplements.filter(\.isActive).count) active", action: {
                            nutritionViewModel.showSupplements = true
                        })
                        Divider().overlay(BeUTheme.divider)
                        meRow(title: "Health history", subtitle: "\(nutritionViewModel.healthHistoryService.conditions.filter(\.isActive).count) active", action: {
                            nutritionViewModel.showHealthHistory = true
                        })
                        Divider().overlay(BeUTheme.divider)
                        meRow(title: "Targets", subtitle: "Calories, protein, Apple Health", action: {
                            nutritionViewModel.showSettings = true
                        })
                    }
                }

                Text(BeUSafetyCopy.wellnessDisclaimer)
                    .font(BeUTheme.helperFont)
                    .foregroundColor(BeUTheme.mutedText)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 160)
        }
    }

    private var bottomFade: some View {
        LinearGradient(
            colors: [
                BeUTheme.background.opacity(0),
                BeUTheme.background.opacity(0.84),
                BeUTheme.background
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 160)
        .allowsHitTesting(false)
    }

    private var currentDateLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEEE · MMMM d"
        return formatter.string(from: Date())
    }

    private var greetingFirstName: String {
        let userId = nutritionViewModel.profile?.userId ?? nutritionViewModel.userId
        let candidate = userId
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .first
            .map(String.init)?
            .capitalized

        guard let candidate, !candidate.isEmpty, candidate.lowercased() != "demo" else {
            return "friend"
        }

        return candidate
    }

    private var currentPlan: DailyPersonalizedActionPlan {
        viewModel.dailyActionPlan ?? PlanService().fallbackDailyPlan(
            userId: nutritionViewModel.userId,
            readiness: viewModel.readinessCard,
            card: viewModel.dailyPlanCard,
            progress: nutritionViewModel.dailyProgress,
            summary: viewModel.todaySummary
        )
    }

    private var currentWeeklyPlan: WeeklyPersonalizedActionPlan {
        viewModel.weeklyActionPlan ?? PlanService().fallbackWeeklyPlan(
            from: currentPlan,
            trend: viewModel.readinessTrendSummary
        )
    }

    private var currentInsights: WeeklyInsightsResponse {
        viewModel.weeklyInsights ?? PlanService().fallbackWeeklyInsights(
            from: viewModel.readinessTrendSummary,
            consistency: nutritionViewModel.consistencyCard
        )
    }

    private var averageWeeklySteps: Int {
        let values = viewModel.weeklySummaries.map(\.steps)
        guard !values.isEmpty else { return 0 }
        return Int((Double(values.reduce(0, +)) / Double(values.count)).rounded())
    }

    private var strengthDescription: String {
        let target = currentPlan.targets.strengthTraining
        switch target.recommendation {
        case .rest:
            return "Rest day · mobility and easy movement"
        case .required:
            return "\(target.durationMinutes) mins · \(target.intensity.rawValue.capitalized)"
        case .optional:
            return "Optional \(target.durationMinutes)-minute session · \(target.intensity.rawValue.capitalized)"
        }
    }

    private var goalSegment: MeGoalSegment {
        guard let profile = nutritionViewModel.profile else { return .maintain }
        switch profile.goalType {
        case .loseWeight:
            return .fatLoss
        case .gainMuscle:
            return .muscle
        case .maintainWeight, .generalWellness:
            return .maintain
        }
    }

    private var weightSummary: String {
        guard let profile = nutritionViewModel.profile else { return "Not set" }
        return String(format: "%.1f kg", profile.currentWeightKg)
    }

    private var heightSummary: String {
        guard let profile = nutritionViewModel.profile else { return "Not set" }
        return "\(Int(profile.heightCm.rounded())) cm"
    }

    private var targetWeightSummary: String {
        guard let value = nutritionViewModel.profile?.targetWeightKg else { return "Not set" }
        return String(format: "%.1f kg", value)
    }

    private var timelineSummary: String {
        nutritionViewModel.profile?.targetTimeline ?? "No timeline"
    }

    private func openMealLogging() {
        if nutritionViewModel.profile == nil {
            nutritionViewModel.showOnboarding = true
        } else {
            nutritionViewModel.showMealLogging = true
        }
    }

    private func openProfile() {
        if nutritionViewModel.profile == nil {
            nutritionViewModel.showOnboarding = true
        } else {
            nutritionViewModel.showProfileGateway = true
        }
    }

    private func updateGoal(_ segment: MeGoalSegment) {
        guard let profile = nutritionViewModel.profile else { return }
        let mappedGoal: NutritionGoalType = switch segment {
        case .fatLoss:
            .loseWeight
        case .maintain:
            .maintainWeight
        case .muscle:
            .gainMuscle
        }

        guard profile.goalType != mappedGoal else { return }

        let updated = UserNutritionProfile(
            userId: profile.userId,
            age: profile.age,
            sex: profile.sex,
            heightCm: profile.heightCm,
            currentWeightKg: profile.currentWeightKg,
            targetWeightKg: profile.targetWeightKg,
            goalType: mappedGoal,
            dailyCalorieTarget: profile.dailyCalorieTarget,
            dailyProteinTargetGrams: profile.dailyProteinTargetGrams,
            dailyCarbTargetGrams: profile.dailyCarbTargetGrams,
            dailyFatTargetGrams: profile.dailyFatTargetGrams,
            targetTimeline: profile.targetTimeline,
            createdAt: profile.createdAt,
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
        nutritionViewModel.updateProfile(updated)
    }

    @ViewBuilder
    private func tabHeader(kicker: String, title: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            KickerText(text: kicker)
            Text(title)
                .font(BeUTheme.greetingHeroFont)
                .foregroundColor(BeUTheme.primaryText)
        }
    }

    @ViewBuilder
    private func numberedHeader(_ number: String, _ title: String) -> some View {
        HStack(spacing: 12) {
            Text(number)
                .font(BeUTheme.kickerFont)
                .tracking(1.6)
                .foregroundColor(BeUTheme.tertiaryText)
            Text(title)
                .font(BeUTheme.sectionTitleFont)
                .foregroundColor(BeUTheme.primaryText)
        }
    }

    @ViewBuilder
    private func planStat(title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            KickerText(text: title)
            Text(value)
                .font(BeUTheme.bigNumber(size: 34))
                .monospacedDigit()
                .foregroundColor(BeUTheme.primaryText)
            Text(subtitle)
                .font(BeUTheme.helperFont)
                .foregroundColor(BeUTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(BeUTheme.cardAltBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(BeUTheme.cardBorder, lineWidth: 0.5)
                )
        )
    }

    @ViewBuilder
    private func activitySummaryRow(title: String, detail: String) -> some View {
        HStack {
            Text(title)
                .font(BeUTheme.bodyFont.weight(.semibold))
                .foregroundColor(BeUTheme.primaryText)
            Spacer()
            Text(detail)
                .font(BeUTheme.helperFont)
                .foregroundColor(BeUTheme.secondaryText)
        }
    }

    @ViewBuilder
    private func reminderRow(text: String) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.03))
                .frame(width: 26, height: 26)
                .overlay(
                    Image(systemName: "pills.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(BeUTheme.accent)
                )
            Text(text)
                .font(BeUTheme.bodyFont)
                .foregroundColor(BeUTheme.secondaryText)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.03))
        )
    }

    @ViewBuilder
    private func statColumn(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(BeUTheme.helperFont)
                .foregroundColor(BeUTheme.secondaryText)
            Text(value)
                .font(BeUTheme.bigNumber(size: 34))
                .monospacedDigit()
                .foregroundColor(BeUTheme.primaryText)
        }
    }

    @ViewBuilder
    private func meRow(title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(BeUTheme.bodyFont.weight(.semibold))
                        .foregroundColor(BeUTheme.primaryText)
                    Text(subtitle)
                        .font(BeUTheme.helperFont)
                        .foregroundColor(BeUTheme.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(BeUTheme.secondaryText)
            }
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }

    private func syncPersonalizationContext() {
        viewModel.updatePersonalizationContext(
            profile: nutritionViewModel.profile,
            progress: nutritionViewModel.dailyProgress,
            supplements: nutritionViewModel.supplementService.supplements,
            healthConditions: nutritionViewModel.healthHistoryService.conditions
        )
    }
}

private enum MeGoalSegment: String, CaseIterable, Identifiable {
    case fatLoss
    case maintain
    case muscle

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fatLoss:
            return "Fat loss"
        case .maintain:
            return "Maintain"
        case .muscle:
            return "Muscle"
        }
    }
}

private struct TodayTargetsCard: View {
    let plan: DailyPersonalizedActionPlan
    let meals: [MealLog]

    var body: some View {
        BeUCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    KickerText(text: "Today's targets")
                    Spacer()
                    HStack(spacing: 8) {
                        ForEach(MealType.allCases) { type in
                            Circle()
                                .fill(loggedMealTypes.contains(type) ? BeUTheme.accent : BeUTheme.neutralTrack)
                                .frame(width: 10, height: 10)
                                .overlay(
                                    Text(type.shortTitle)
                                        .font(.system(size: 7, weight: .bold))
                                        .foregroundColor(loggedMealTypes.contains(type) ? .white : BeUTheme.tertiaryText)
                                )
                        }
                    }
                }

                DashboardTargetBar(
                    label: "Calories",
                    valueText: "\(plan.progress.caloriesConsumed)",
                    targetText: "\(plan.targets.calories)",
                    value: Double(plan.progress.caloriesConsumed),
                    target: Double(max(plan.targets.calories, 1)),
                    tint: BeUTheme.accent
                )
                Text("\(max(plan.progress.caloriesRemaining, 0)) kcal remaining")
                    .font(BeUTheme.helperFont)
                    .foregroundColor(BeUTheme.secondaryText)

                Divider().overlay(BeUTheme.divider)

                HStack(spacing: 18) {
                    MacroRing(
                        title: "Protein",
                        value: plan.progress.proteinConsumedGrams,
                        target: Double(plan.targets.proteinGrams),
                        color: BeUTheme.accent
                    )
                    .frame(maxWidth: .infinity)

                    MacroRing(
                        title: "Carbs",
                        value: Double(max(plan.progress.caloriesConsumed / 4, 0)),
                        target: nil,
                        color: BeUTheme.macroCarb
                    )
                    .frame(maxWidth: .infinity)

                    MacroRing(
                        title: "Water",
                        value: plan.progress.waterConsumedLiters,
                        target: plan.targets.waterLiters,
                        color: BeUTheme.macroFat,
                        unit: "L",
                        showsOneDecimal: true
                    )
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var loggedMealTypes: Set<MealType> {
        Set(meals.map(\.mealType))
    }
}

private struct ActionPlanOverviewCard: View {
    let plan: DailyPersonalizedActionPlan
    let onOpenPlan: () -> Void

    var body: some View {
        BeUCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(BeUTheme.accent.opacity(0.13))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: "sparkles")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(BeUTheme.accent)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        KickerText(text: "Today's plan")
                        Text(plan.planSummary)
                            .font(BeUTheme.bodyFont.weight(.semibold))
                            .foregroundColor(BeUTheme.primaryText)
                    }
                }

                HStack(spacing: 12) {
                    planTile(
                        title: plan.targets.strengthTraining.recommendation == .rest ? "Strength" : "Training",
                        value: plan.targets.strengthTraining.recommendation == .rest ? "Rest day" : "\(plan.targets.strengthTraining.durationMinutes) mins",
                        subtitle: plan.targets.strengthTraining.intensity.rawValue.capitalized
                    )
                    planTile(
                        title: "Cardio",
                        value: "\(plan.progress.stepsRemaining)",
                        subtitle: "steps remaining"
                    )
                }

                Button("Open full plan", action: onOpenPlan)
                    .buttonStyle(BeUSecondaryButtonStyle())
            }
        }
    }

    private func planTile(title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            KickerText(text: title)
            Text(value)
                .font(BeUTheme.bigNumber(size: 28))
                .monospacedDigit()
                .foregroundColor(BeUTheme.primaryText)
            Text(subtitle)
                .font(BeUTheme.helperFont)
                .foregroundColor(BeUTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(BeUTheme.cardAltBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(BeUTheme.cardBorder, lineWidth: 0.5)
                )
        )
    }
}

private struct NudgesCard: View {
    let nudges: [DailyPersonalizedNudge]

    var body: some View {
        BeUCard {
            VStack(alignment: .leading, spacing: 14) {
                KickerText(text: "Real-time nudges")
                if nudges.isEmpty {
                    Text("You’re on track — nice consistency today.")
                        .font(BeUTheme.bodyFont)
                        .foregroundColor(BeUTheme.secondaryText)
                } else {
                    ForEach(nudges) { nudge in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(nudge.message)
                                .font(BeUTheme.bodyFont.weight(.semibold))
                                .foregroundColor(BeUTheme.primaryText)
                            Text(nudge.reason)
                                .font(BeUTheme.helperFont)
                                .foregroundColor(BeUTheme.secondaryText)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(backgroundColor(for: nudge.tone))
                        )
                    }
                }
            }
        }
    }

    private func backgroundColor(for tone: EngineNudgeTone) -> Color {
        switch tone {
        case .win:
            return BeUTheme.macroFat.opacity(0.16)
        case .alert:
            return BeUTheme.lowStatus.opacity(0.1)
        case .soft:
            return BeUTheme.accent.opacity(0.1)
        }
    }
}

private struct QuickActionsCard: View {
    let onLogMeal: () -> Void
    let onLogWater: () -> Void

    var body: some View {
        BeUCard {
            VStack(alignment: .leading, spacing: 14) {
                KickerText(text: "Quick actions")
                Button(action: onLogMeal) {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 52, height: 52)
                            .overlay(
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                            )
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Log a meal")
                                .font(BeUTheme.buttonFont)
                                .foregroundColor(BeUTheme.buttonText)
                            Text("Snap a photo, we'll do the rest")
                                .font(.system(size: 12.5))
                                .foregroundColor(.white.opacity(0.72))
                        }
                        Spacer()
                        Circle()
                            .fill(BeUTheme.accent)
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(BeUTheme.primaryText)
                            )
                    }
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(BeUTheme.buttonBackground)
                    )
                }
                .buttonStyle(.plain)

                Button(action: onLogWater) {
                    Text("Log water (+100 ml)")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(BeUSecondaryButtonStyle())
            }
        }
    }
}

private struct WeeklySnapshotCard: View {
    let insights: WeeklyInsightsResponse
    let readinessSummary: ReadinessTrendSummary
    let consistency: ConsistencyCardModel
    let onOpenProgress: () -> Void

    var body: some View {
        Button(action: onOpenProgress) {
            BeUCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            KickerText(text: "Weekly snapshot")
                            Text("Averages and momentum")
                                .font(BeUTheme.bodyFont.weight(.semibold))
                                .foregroundColor(BeUTheme.primaryText)
                        }
                        Spacer()
                        Text("See more")
                            .font(BeUTheme.helperFont.weight(.semibold))
                            .foregroundColor(BeUTheme.accent)
                    }

                    HStack {
                        stat(title: "Avg readiness", value: readinessSummary.averageScore.map(String.init) ?? "—")
                        Spacer()
                        stat(title: "Consistency", value: "\(insights.consistencyScore)")
                    }

                    Text(readinessSummary.summaryMessage)
                        .font(BeUTheme.helperFont)
                        .foregroundColor(BeUTheme.secondaryText)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func stat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(BeUTheme.helperFont)
                .foregroundColor(BeUTheme.secondaryText)
            Text(value)
                .font(BeUTheme.bigNumber(size: 32))
                .monospacedDigit()
                .foregroundColor(BeUTheme.primaryText)
        }
    }
}

private struct SyncStatusCard: View {
    let lines: [String]

    var body: some View {
        BeUCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Sync Status")
                    .font(BeUTheme.sectionTitleFont)
                    .foregroundColor(BeUTheme.primaryText)
                ForEach(lines, id: \.self) { line in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(BeUTheme.accent)
                        Text(line)
                            .font(BeUTheme.helperFont)
                            .foregroundColor(BeUTheme.secondaryText)
                    }
                }
            }
        }
    }
}

private struct DebugHealthCard: View {
    let lines: [String]
    let onTest: () -> Void

    var body: some View {
        BeUCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Debug HealthKit")
                    .font(BeUTheme.sectionTitleFont)
                    .foregroundColor(BeUTheme.primaryText)
                ForEach(lines, id: \.self) { line in
                    Text(line)
                        .font(BeUTheme.helperFont)
                        .foregroundColor(BeUTheme.secondaryText)
                }
                Button("Test Step Sync", action: onTest)
                    .buttonStyle(BeUPrimaryButtonStyle())
            }
        }
    }
}

struct DashboardTargetBar: View {
    var label: String? = nil
    var valueText: String? = nil
    var targetText: String? = nil
    let value: Double
    let target: Double
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let label {
                HStack {
                    Text(label)
                        .font(BeUTheme.bodyFont.weight(.semibold))
                        .foregroundColor(BeUTheme.primaryText)
                    Spacer()
                    if let valueText, let targetText {
                        Text("\(valueText) / \(targetText)")
                            .font(BeUTheme.helperFont)
                            .foregroundColor(BeUTheme.secondaryText)
                    }
                }
            }

            GeometryReader { proxy in
                let width = proxy.size.width
                let progress = target > 0 ? min(max(value / target, 0), 1) : 0
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(BeUTheme.neutralTrack)
                    .frame(height: 8)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [tint.opacity(0.75), tint],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: width * progress, height: 8)
                    }
            }
            .frame(height: 8)
        }
    }
}

private extension MealType {
    var shortTitle: String {
        switch self {
        case .breakfast: return "B"
        case .lunch: return "L"
        case .dinner: return "D"
        case .snack: return "S"
        }
    }
}
