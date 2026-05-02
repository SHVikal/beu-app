import PhotosUI
import SwiftUI
import UIKit

struct OnboardingView: View {
    let userId: String
    let onComplete: (UserNutritionProfile) -> Void

    @State private var step = 0
    @State private var ageText = ""
    @State private var selectedSex: NutritionProfileSex = .preferNotToSay
    @State private var heightText = ""
    @State private var currentWeightText = ""
    @State private var goalType: NutritionGoalType = .generalWellness
    @State private var targetWeightText = ""
    @State private var targetTimeline = ""
    @State private var manualOverrideTargets = false
    @State private var calorieTargetText = ""
    @State private var proteinTargetText = ""
    @State private var carbTargetText = ""
    @State private var fatTargetText = ""
    @State private var errorMessage: String?

    private let totalSteps = 5

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ProgressView(value: Double(step + 1), total: Double(totalSteps))
                        .tint(BeUTheme.accent)

                    switch step {
                    case 0:
                        WelcomeStepView(onContinue: advance)
                    case 1:
                        BasicProfileView(
                            ageText: $ageText,
                            selectedSex: $selectedSex,
                            heightText: $heightText,
                            currentWeightText: $currentWeightText,
                            onContinue: {
                                if validateProfile() { advance() }
                            }
                        )
                    case 2:
                        GoalSetupView(
                            goalType: $goalType,
                            targetWeightText: $targetWeightText,
                            targetTimeline: $targetTimeline,
                            onContinue: {
                                updateSuggestedTargets()
                                advance()
                            }
                        )
                    case 3:
                        NutritionTargetView(
                            suggestion: suggestedTargets,
                            manualOverrideTargets: $manualOverrideTargets,
                            calorieTargetText: $calorieTargetText,
                            proteinTargetText: $proteinTargetText,
                            carbTargetText: $carbTargetText,
                            fatTargetText: $fatTargetText,
                            onContinue: {
                                if validateTargets() { advance() }
                            }
                        )
                    default:
                        OnboardingSummaryView(
                            summaryLines: summaryLines,
                            onStart: finishOnboarding
                        )
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(BeUTheme.helperFont)
                            .foregroundColor(BeUTheme.lowStatus)
                    }
                }
                .padding(24)
            }
            .background(BeUTheme.background.ignoresSafeArea())
            .navigationTitle("BeU Setup")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            updateSuggestedTargets()
        }
        .tint(BeUTheme.primaryText)
    }

    private var suggestedTargets: NutritionTargetSuggestion? {
        guard let height = Double(heightText), let weight = Double(currentWeightText) else {
            return nil
        }
        return NutritionTargetCalculator.estimateTargets(
            age: Int(ageText),
            sex: selectedSex,
            heightCm: height,
            weightKg: weight,
            goalType: goalType
        )
    }

    private var summaryLines: [String] {
        [
            "Current weight: \(currentWeightText.isEmpty ? "--" : "\(currentWeightText) kg")",
            "Target weight: \(targetWeightText.isEmpty ? "Not set" : "\(targetWeightText) kg")",
            "Daily calorie target: \(calorieTargetText.isEmpty ? "--" : calorieTargetText)",
            "Daily protein target: \(proteinTargetText.isEmpty ? "--" : "\(proteinTargetText)g")",
            "Goal type: \(goalType.title)"
        ]
    }

    private func advance() {
        errorMessage = nil
        withAnimation(.easeInOut(duration: 0.2)) {
            step = min(step + 1, totalSteps - 1)
        }
    }

    private func validateProfile() -> Bool {
        guard Int(ageText) != nil, Double(heightText) != nil, Double(currentWeightText) != nil else {
            errorMessage = "Please complete age, height, and current weight before continuing."
            return false
        }
        return true
    }

    private func validateTargets() -> Bool {
        guard let calories = Int(calorieTargetText), let protein = Int(proteinTargetText) else {
            errorMessage = "Calories and protein target are required."
            return false
        }
        let minimum = NutritionTargetCalculator.minimumCalories(for: selectedSex)
        guard calories >= minimum else {
            errorMessage = "Daily calories must be at least \(minimum) for the selected profile."
            return false
        }
        guard protein > 0 else {
            errorMessage = "Protein target must be greater than zero."
            return false
        }
        return true
    }

    private func updateSuggestedTargets() {
        guard let suggestion = suggestedTargets, !manualOverrideTargets else { return }
        calorieTargetText = String(suggestion.calories)
        proteinTargetText = String(suggestion.proteinGrams)
        carbTargetText = suggestion.carbsGrams.map(String.init) ?? ""
        fatTargetText = suggestion.fatGrams.map(String.init) ?? ""
    }

    private func finishOnboarding() {
        guard validateTargets(),
              let height = Double(heightText),
              let currentWeight = Double(currentWeightText),
              let calories = Int(calorieTargetText),
              let protein = Int(proteinTargetText) else {
            return
        }

        let now = ISO8601DateFormatter().string(from: Date())
        let profile = UserNutritionProfile(
            userId: userId,
            age: Int(ageText),
            sex: selectedSex,
            heightCm: height,
            currentWeightKg: currentWeight,
            targetWeightKg: Double(targetWeightText),
            goalType: goalType,
            dailyCalorieTarget: calories,
            dailyProteinTargetGrams: protein,
            dailyCarbTargetGrams: Int(carbTargetText),
            dailyFatTargetGrams: Int(fatTargetText),
            targetTimeline: targetTimeline.isEmpty ? nil : targetTimeline,
            createdAt: now,
            updatedAt: now
        )
        onComplete(profile)
    }
}

private struct WelcomeStepView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Personalize your nutrition plan")
                .font(.largeTitle.weight(.bold))
                .foregroundColor(BeUTheme.primaryText)
            Text("We’ll use your activity, recovery, and goals to estimate your daily nutrition targets.")
                .font(BeUTheme.bodyFont)
                .foregroundColor(BeUTheme.secondaryText)
            Text("These targets are estimates and can be adjusted anytime.")
                .font(BeUTheme.helperFont)
                .foregroundColor(BeUTheme.mutedText)
            Button("Continue", action: onContinue)
                .buttonStyle(BeUPrimaryButtonStyle())
        }
    }
}

struct BasicProfileView: View {
    @Binding var ageText: String
    @Binding var selectedSex: NutritionProfileSex
    @Binding var heightText: String
    @Binding var currentWeightText: String
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Basic Profile")
                .font(BeUTheme.titleFont)
                .foregroundColor(BeUTheme.primaryText)
            OnboardingNumberField(title: "Age", text: $ageText)
            Picker("Sex", selection: $selectedSex) {
                ForEach(NutritionProfileSex.allCases) { sex in
                    Text(sex.title).tag(sex)
                }
            }
            .beuSegmentedControlStyle()
            OnboardingNumberField(title: "Height (cm)", text: $heightText)
            OnboardingNumberField(title: "Current weight (kg)", text: $currentWeightText)
            Button("Continue", action: onContinue)
                .buttonStyle(BeUPrimaryButtonStyle())
        }
    }
}

struct GoalSetupView: View {
    @Binding var goalType: NutritionGoalType
    @Binding var targetWeightText: String
    @Binding var targetTimeline: String
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Goal Setup")
                .font(BeUTheme.titleFont)
                .foregroundColor(BeUTheme.primaryText)
            Picker("Goal type", selection: $goalType) {
                ForEach(NutritionGoalType.allCases) { goal in
                    Text(goal.title).tag(goal)
                }
            }
            .beuMenuPickerStyle()
            OnboardingNumberField(title: "Target weight (kg)", text: $targetWeightText)
            OnboardingTextField(title: "Target timeline (optional)", text: $targetTimeline)
            Button("Continue", action: onContinue)
                .buttonStyle(BeUPrimaryButtonStyle())
        }
    }
}

struct NutritionTargetView: View {
    let suggestion: NutritionTargetSuggestion?
    @Binding var manualOverrideTargets: Bool
    @Binding var calorieTargetText: String
    @Binding var proteinTargetText: String
    @Binding var carbTargetText: String
    @Binding var fatTargetText: String
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Daily Nutrition Target")
                .font(BeUTheme.titleFont)
                .foregroundColor(BeUTheme.primaryText)
            Text("These targets are estimates and can be adjusted anytime.")
                .font(BeUTheme.helperFont)
                .foregroundColor(BeUTheme.mutedText)

            if let suggestion {
                WellnessFormCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Suggested targets")
                            .font(BeUTheme.sectionTitleFont)
                            .foregroundColor(BeUTheme.primaryText)
                        Text("\(suggestion.calories) calories")
                            .font(BeUTheme.bodyFont)
                            .foregroundColor(BeUTheme.secondaryText)
                        Text("\(suggestion.proteinGrams)g protein")
                            .font(BeUTheme.bodyFont)
                            .foregroundColor(BeUTheme.secondaryText)
                        if let carbs = suggestion.carbsGrams {
                            Text("\(carbs)g carbs")
                                .font(BeUTheme.bodyFont)
                                .foregroundColor(BeUTheme.secondaryText)
                        }
                        if let fat = suggestion.fatGrams {
                            Text("\(fat)g fat")
                                .font(BeUTheme.bodyFont)
                                .foregroundColor(BeUTheme.secondaryText)
                        }
                    }
                }
            }

            Toggle("Manually override targets", isOn: $manualOverrideTargets)
                .font(BeUTheme.bodyFont)
                .foregroundColor(BeUTheme.primaryText)
                .tint(BeUTheme.accent)

            OnboardingNumberField(title: "Daily calorie target", text: $calorieTargetText)
            OnboardingNumberField(title: "Daily protein target (g)", text: $proteinTargetText)
            OnboardingNumberField(title: "Daily carb target (optional)", text: $carbTargetText)
            OnboardingNumberField(title: "Daily fat target (optional)", text: $fatTargetText)

            Button("Continue", action: onContinue)
                .buttonStyle(BeUPrimaryButtonStyle())
        }
    }
}

struct OnboardingSummaryView: View {
    let summaryLines: [String]
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Confirmation")
                .font(BeUTheme.titleFont)
                .foregroundColor(BeUTheme.primaryText)

            WellnessFormCard {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(summaryLines, id: \.self) { line in
                        Text(line)
                            .font(BeUTheme.bodyFont)
                            .foregroundColor(BeUTheme.primaryText)
                    }
                }
            }

            Button("Start tracking", action: onStart)
                .buttonStyle(BeUPrimaryButtonStyle())
        }
    }
}

struct DailyNutritionCounterCard: View {
    let progress: DailyNutritionProgress?
    let mealCount: Int
    let onOpenHistory: () -> Void

    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Daily Nutrition")
                        .font(BeUTheme.sectionTitleFont)
                        .foregroundColor(BeUTheme.primaryText)
                    Spacer()
                    Button("Meal history", action: onOpenHistory)
                        .font(BeUTheme.helperFont.weight(.semibold))
                        .foregroundColor(BeUTheme.accent)
                }

                if let progress {
                    VStack(alignment: .leading, spacing: 10) {
                        NutritionMetricRow(
                            title: "Calories",
                            consumedText: "\(progress.consumedCalories) / \(progress.calorieTarget)",
                            remainingText: progress.remainingCalories >= 0 ? "\(progress.remainingCalories) remaining" : "Over by \(abs(progress.remainingCalories))",
                            progress: progress.calorieTarget > 0 ? min(Double(progress.consumedCalories) / Double(progress.calorieTarget), 1) : 0
                        )

                        NutritionMetricRow(
                            title: "Protein",
                            consumedText: "\(Int(progress.consumedProteinGrams.rounded()))g / \(progress.proteinTargetGrams)g",
                            remainingText: progress.remainingProteinGrams >= 0 ? "\(Int(progress.remainingProteinGrams.rounded()))g remaining" : "Exceeded by \(Int(abs(progress.remainingProteinGrams).rounded()))g",
                            progress: progress.proteinTargetGrams > 0 ? min(progress.consumedProteinGrams / Double(progress.proteinTargetGrams), 1) : 0
                        )

                        Text("\(mealCount) meal\(mealCount == 1 ? "" : "s") logged today")
                            .font(BeUTheme.helperFont)
                            .foregroundColor(BeUTheme.mutedText)
                    }
                } else {
                    Text("Complete onboarding to see your calorie and protein targets.")
                        .font(BeUTheme.helperFont)
                        .foregroundColor(BeUTheme.mutedText)
                }
            }
        }
    }
}

struct LogMealCard: View {
    let onTap: () -> Void

    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Log Meal")
                    .font(BeUTheme.sectionTitleFont)
                    .foregroundColor(BeUTheme.primaryText)
                Text("Take a photo to estimate calories and macros.")
                    .font(BeUTheme.helperFont)
                    .foregroundColor(BeUTheme.mutedText)
                Button("Log meal", action: onTap)
                    .buttonStyle(BeUPrimaryButtonStyle())
            }
        }
    }
}

struct MealPhotoLoggingFlowView: View {
    let userId: String
    let onSaveMeal: (UIImage, FoodImageAnalysis, MealType) -> Void
    let progressProvider: () -> DailyNutritionProgress?

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = MealLoggingViewModel()
    @State private var photosPickerItem: PhotosPickerItem?
    @State private var analysis: FoodImageAnalysis?
    @State private var mealType: MealType = .lunch
    @State private var showSuccess = false
    @State private var flowState: MealLoggingState = .idle

    private let analysisService = RealFoodImageAnalysisService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    mealFlowTopBar
                    MealLoggingEntryCard()
                    photoPickerSection
                    previewAndAnalyzeSection
                    loadingSection
                    emptyResultSection
                    analysisReviewSection
                    successSection
                    failureSection
                    disclaimerFooterSection
                }
                .padding(20)
            }
            .background(BeUTheme.background.ignoresSafeArea())
            .navigationBarBackButtonHidden(true)
        }
        .fullScreenCover(isPresented: $viewModel.isShowingCamera) {
            CameraPickerView { image in
                setSelectedImage(image)
            }
        }
        .onChange(of: photosPickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    setSelectedImage(image)
                }
            }
        }
        .onChange(of: viewModel.selectedImage) { _, image in
            if image == nil {
                flowState = .idle
            } else if flowState == .idle {
                flowState = .imageSelected
            }
        }
        .alert("Camera access is disabled", isPresented: $viewModel.cameraPermissionDenied) {
            Button("Open Settings") {
                viewModel.openSettings()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Camera access is disabled. Enable it in Settings to take meal photos.")
        }
        .tint(BeUTheme.primaryText)
    }

    private func analyze(image: UIImage) async {
        flowState = .uploading
        viewModel.errorMessage = nil

        do {
            flowState = .analyzing
            analysis = try await viewModel.analyzeSelectedImage { selected in
                try await analysisService.analyzeFoodImage(selected, userId: userId)
            }
            showSuccess = false
            flowState = analysis?.detectedItems.isEmpty == true ? .emptyFoodResult : .success
        } catch {
            viewModel.errorMessage = error.localizedDescription
            flowState = .failed
        }
    }

    private var hasSelectedImage: Bool {
        viewModel.selectedImage != nil
    }

    @ViewBuilder
    private var mealFlowTopBar: some View {
        HStack(spacing: 12) {
            Button(action: handleBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BeUTheme.primaryText)
            }

            Spacer()

            Text(topBarTitle)
                .font(.headline.weight(.semibold))
                .foregroundStyle(BeUTheme.primaryText)

            Spacer()

            if hasSelectedImage {
                Button("Clear image", action: resetMealFlow)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BeUTheme.primaryText)
            } else {
                Color.clear
                    .frame(width: 84, height: 20)
            }
        }
    }

    @ViewBuilder
    private var photoPickerSection: some View {
        MealPhotoPickerView(
            selectedImage: viewModel.selectedImage,
            photosPickerItem: $photosPickerItem,
            onCameraTap: { viewModel.takePhotoTapped() },
            onGalleryTap: { viewModel.uploadFromGalleryTapped() }
        )
    }

    @ViewBuilder
    private var previewAndAnalyzeSection: some View {
        if let selectedImage = viewModel.selectedImage {
            MealImagePreviewView(image: selectedImage)

            if analysis == nil && !showSuccess {
                analyzeButton(for: selectedImage)
            }
        }
    }

    @ViewBuilder
    private var loadingSection: some View {
        if flowState == .uploading || flowState == .analyzing {
            FoodAnalysisLoadingView()
        }
    }

    @ViewBuilder
    private var emptyResultSection: some View {
        if flowState == .emptyFoodResult {
            EmptyFoodResultCard {
                analysis = makeManualAnalysis()
                flowState = .success
            }
        }
    }

    @ViewBuilder
    private var analysisReviewSection: some View {
        if let analysis, (flowState == .success || showSuccess) {
            DetectedFoodReviewView(
                analysis: analysis,
                onUpdate: { self.analysis = $0 },
                analysisService: analysisService
            )
            MacroEstimateView(analysis: analysis)
            MealTypeSelector(selectedMealType: $mealType)

            Button("Log meal") {
                guard let selectedImage = viewModel.selectedImage else { return }
                onSaveMeal(selectedImage, analysis, mealType)
                showSuccess = true
            }
            .buttonStyle(BeUPrimaryButtonStyle())
            .disabled(analysis.detectedItems.isEmpty)

            if analysis.detectedItems.isEmpty {
                Text("Add at least one item before logging this meal.")
                    .font(.footnote)
                    .foregroundStyle(BeUTheme.lowStatus)
            }
        }
    }

    @ViewBuilder
    private var disclaimerFooterSection: some View {
        if !disclaimerLines.isEmpty {
            MealLoggingDisclaimerFooter(lines: disclaimerLines)
        }
    }

    @ViewBuilder
    private var successSection: some View {
        if showSuccess, let analysis {
            MealLoggedSuccessView(
                analysis: analysis,
                mealType: mealType,
                progress: progressProvider()
            ) {
                dismiss()
            }
        }
    }

    @ViewBuilder
    private var failureSection: some View {
        if let errorMessage = viewModel.errorMessage {
            FailedAnalysisCard(message: errorMessage) {
                analysis = makeManualAnalysis()
                flowState = .success
                self.viewModel.errorMessage = nil
            }
        }
    }

    private func analyzeButton(for image: UIImage) -> some View {
        Button {
            Task { await analyze(image: image) }
        } label: {
            if flowState == .uploading || flowState == .analyzing {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                Text("Analyze meal")
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(BeUPrimaryButtonStyle())
        .disabled(flowState == .uploading || flowState == .analyzing)
    }

    private var topBarTitle: String {
        if flowState == .success || showSuccess {
            return "Estimated nutrition"
        }

        return "BeU Meal Log"
    }

    private var disclaimerLines: [String] {
        if showSuccess || flowState == .success {
            return [
                "Photo estimates can be imperfect. Please confirm the items and portions before logging.",
                "Estimated values can be adjusted before logging.",
                "These numbers are estimates based on visible items and portion sizes."
            ]
        }

        if flowState == .imageSelected || flowState == .uploading || flowState == .analyzing || flowState == .emptyFoodResult || flowState == .failed {
            return [
                "Photo estimates can be imperfect. Please confirm the items and portions before logging.",
                "Estimated values can be adjusted before logging."
            ]
        }

        return []
    }

    private func handleBack() {
        if showSuccess {
            showSuccess = false
            flowState = analysis?.detectedItems.isEmpty == true ? .emptyFoodResult : .success
            return
        }

        switch flowState {
        case .success, .emptyFoodResult, .failed, .uploading, .analyzing:
            analysis = nil
            viewModel.errorMessage = nil
            flowState = viewModel.selectedImage == nil ? .idle : .imageSelected
        case .imageSelected:
            resetMealFlow()
        case .idle:
            dismiss()
        }
    }

    private func resetMealFlow() {
        viewModel.clearSelectedImage()
        photosPickerItem = nil
        analysis = nil
        mealType = .lunch
        showSuccess = false
        flowState = .idle
    }

    private func setSelectedImage(_ image: UIImage) {
        viewModel.setSelectedImage(image)
        analysis = nil
        mealType = .lunch
        showSuccess = false
        flowState = .imageSelected
    }

    private func makeManualAnalysis() -> FoodImageAnalysis {
        FoodImageAnalysis(
            id: UUID().uuidString,
            userId: userId,
            inputType: "image",
            originalDescription: nil,
            imageLocalPath: nil,
            imageRemoteUrl: nil,
            detectedItems: [],
            totalCalories: 0,
            totalProteinGrams: 0,
            totalCarbsGrams: 0,
            totalFatGrams: 0,
            confidence: "low",
            notes: [
                "Nutrition values are estimates based on visible food items.",
                "Please confirm items and portions before logging."
            ],
            createdAt: ISO8601DateFormatter().string(from: Date())
        )
    }
}

private struct MealLoggingEntryCard: View {
    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Choose a photo to estimate calories and macros, then review before saving.")
                    .font(.footnote)
                    .foregroundStyle(BeUTheme.helperText)
            }
        }
    }
}

struct MealPhotoPickerView: View {
    let selectedImage: UIImage?
    @Binding var photosPickerItem: PhotosPickerItem?
    let onCameraTap: () -> Void
    let onGalleryTap: () -> Void

    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Choose meal photo")
                    .font(.headline)
                    .foregroundStyle(BeUTheme.primaryText)
                HStack(spacing: 12) {
                    Button("Take photo", action: onCameraTap)
                        .buttonStyle(BeUPrimaryButtonStyle())
                    PhotosPicker(selection: $photosPickerItem, matching: .images) {
                        Text("Upload from gallery")
                            .frame(maxWidth: .infinity)
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        onGalleryTap()
                    })
                    .buttonStyle(BeUSecondaryButtonStyle())
                }

                #if targetEnvironment(simulator)
                Text("Camera capture requires a physical device. Use upload from gallery on simulator.")
                    .font(.footnote)
                    .foregroundStyle(BeUTheme.helperText)
                #endif
            }
        }
    }
}

struct MealImagePreviewView: View {
    let image: UIImage

    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Image preview")
                    .font(.headline)
                    .foregroundStyle(BeUTheme.primaryText)
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
    }
}

struct FoodAnalysisLoadingView: View {
    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Analyzing your meal...")
                    .font(.headline)
                    .foregroundStyle(BeUTheme.primaryText)
                ProgressView()
            }
        }
    }
}

struct DetectedFoodReviewView: View {
    let analysis: FoodImageAnalysis
    let onUpdate: (FoodImageAnalysis) -> Void
    let analysisService: FoodImageAnalysisService

    @State private var draftItems: [DetectedFoodItem] = []
    @State private var showAddItem = false
    @State private var newItemName = ""

    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Review detected items")
                    .font(.headline)
                    .foregroundStyle(BeUTheme.primaryText)

                ForEach(Array(draftItems.enumerated()), id: \.element.id) { index, item in
                    DetectedFoodItemRow(item: item) { updated in
                        draftItems[index] = updated
                        pushUpdate()
                    } onRemove: {
                        draftItems.removeAll { $0.id == item.id }
                        pushUpdate()
                    }
                }

                if showAddItem {
                    HStack {
                        BeUTextField(placeholder: "Add missing item", text: $newItemName)
                        Button("Add") {
                            let item = NutritionLookupService().buildItem(name: newItemName.isEmpty ? "Custom item" : newItemName, confidence: "low", userConfirmed: true)
                            draftItems.append(item)
                            newItemName = ""
                            showAddItem = false
                            pushUpdate()
                        }
                    }
                }

                HStack {
                    Button(showAddItem ? "Cancel" : "Add missing item") {
                        showAddItem.toggle()
                    }
                    .buttonStyle(BeUSecondaryButtonStyle())

                    Spacer()

                    Button("Confirm items") {
                        let confirmed = draftItems.map {
                            var item = $0
                            item.userConfirmed = true
                            return item
                        }
                        draftItems = confirmed
                        pushUpdate()
                    }
                    .buttonStyle(BeUPrimaryButtonStyle())
                }
            }
        }
        .onAppear {
            draftItems = analysis.detectedItems
        }
    }

    private func pushUpdate() {
        Task {
            if let updated = try? await analysisService.updateDetectedItems(draftItems, userId: analysis.userId, imageLocalPath: analysis.imageLocalPath, analysisId: analysis.id) {
                await MainActor.run {
                    onUpdate(updated)
                }
            }
        }
    }
}

struct DetectedFoodItemRow: View {
    let item: DetectedFoodItem
    let onUpdate: (DetectedFoodItem) -> Void
    let onRemove: () -> Void

    @State private var name: String
    @State private var portion: String
    @State private var grams: Double
    @State private var calories: String
    @State private var protein: String
    @State private var carbs: String
    @State private var fat: String

    init(item: DetectedFoodItem, onUpdate: @escaping (DetectedFoodItem) -> Void, onRemove: @escaping () -> Void) {
        self.item = item
        self.onUpdate = onUpdate
        self.onRemove = onRemove
        _name = State(initialValue: item.name)
        _portion = State(initialValue: item.estimatedPortion)
        _grams = State(initialValue: item.quantityGrams ?? 100)
        _calories = State(initialValue: String(item.calories))
        _protein = State(initialValue: String(format: "%.1f", item.proteinGrams))
        _carbs = State(initialValue: String(format: "%.1f", item.carbsGrams))
        _fat = State(initialValue: String(format: "%.1f", item.fatGrams))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(item.confidence.capitalized)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(item.confidence == "high" ? .green : item.confidence == "medium" ? .orange : .red)
                Spacer()
                Button(role: .destructive, action: onRemove) {
                    Image(systemName: "trash")
                }
            }

            BeUTextField(placeholder: "Food name", text: $name)
                .onSubmit { pushUpdate() }

            BeUTextField(placeholder: "Estimated portion", text: $portion)
                .onSubmit { pushUpdate() }

            Stepper(value: $grams, in: 20...600, step: 10) {
                Text("Estimated amount: \(Int(grams))g")
                    .foregroundStyle(BeUTheme.primaryText)
            }
            .tint(BeUTheme.accentPink)
            .onChange(of: grams) { _, _ in pushUpdate() }

            HStack(spacing: 10) {
                NumericEntryField(title: "Calories", text: $calories, onCommit: pushUpdate)
                NumericEntryField(title: "Protein", text: $protein, suffix: "g", onCommit: pushUpdate)
            }

            HStack(spacing: 10) {
                NumericEntryField(title: "Carbs", text: $carbs, suffix: "g", onCommit: pushUpdate)
                NumericEntryField(title: "Fat", text: $fat, suffix: "g", onCommit: pushUpdate)
            }
        }
        .padding(12)
        .background(BeUTheme.cardAltBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func pushUpdate() {
        let updated = DetectedFoodItem(
            id: item.id,
            name: name,
            estimatedPortion: portion,
            quantityGrams: grams,
            confidence: item.confidence,
            calories: max(0, Int(calories) ?? 0),
            proteinGrams: max(0, Double(protein) ?? 0),
            carbsGrams: max(0, Double(carbs) ?? 0),
            fatGrams: max(0, Double(fat) ?? 0),
            userConfirmed: item.userConfirmed
        )
        onUpdate(updated)
    }
}

struct MacroEstimateView: View {
    let analysis: FoodImageAnalysis

    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Estimated nutrition")
                    .font(.headline)
                    .foregroundStyle(BeUTheme.primaryText)

                HStack(spacing: 12) {
                    MetricChip(title: "Calories", value: "\(analysis.totalCalories)")
                    MetricChip(title: "Protein", value: "\(Int(analysis.totalProteinGrams.rounded()))g")
                }

                HStack(spacing: 12) {
                    MetricChip(title: "Carbs", value: "\(Int(analysis.totalCarbsGrams.rounded()))g")
                    MetricChip(title: "Fat", value: "\(Int(analysis.totalFatGrams.rounded()))g")
                }
            }
        }
    }
}

private struct EmptyFoodResultCard: View {
    let onAddManually: () -> Void

    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Review detected items")
                    .font(.headline)
                    .foregroundStyle(BeUTheme.primaryText)
                Text("We could not clearly identify food in this image. Try another photo or add items manually.")
                    .font(.footnote)
                    .foregroundStyle(BeUTheme.helperText)
                Button("Add items manually", action: onAddManually)
                    .buttonStyle(BeUPrimaryButtonStyle())
            }
        }
    }
}

private struct NumericEntryField: View {
    let title: String
    @Binding var text: String
    var suffix: String = ""
    let onCommit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(BeUTheme.secondaryText)
            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(suffix.isEmpty ? title : "\(title) (\(suffix))")
                        .font(BeUTheme.bodyFont)
                        .foregroundColor(BeUTheme.inputPlaceholder)
                        .padding(.horizontal, 14)
                }
                TextField("", text: $text)
                    .keyboardType(.decimalPad)
                    .beuInputFieldStyle()
                    .onSubmit(onCommit)
                    .onChange(of: text) { _, _ in
                        onCommit()
                    }
            }
        }
    }
}

private struct FailedAnalysisCard: View {
    let message: String
    let onAddManually: () -> Void

    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(BeUTheme.lowStatus)
                Button("Add items manually", action: onAddManually)
                    .buttonStyle(BeUSecondaryButtonStyle())
            }
        }
    }
}

private enum MealLoggingState {
    case idle
    case imageSelected
    case uploading
    case analyzing
    case success
    case emptyFoodResult
    case failed
}

struct MealTypeSelector: View {
    @Binding var selectedMealType: MealType

    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Meal type")
                    .font(.headline)
                    .foregroundStyle(BeUTheme.primaryText)
                Picker("Meal type", selection: $selectedMealType) {
                    ForEach(MealType.allCases) { type in
                        Text(type.title).tag(type)
                    }
                }
                .beuSegmentedControlStyle()
            }
        }
    }
}

struct MealLoggedSuccessView: View {
    let analysis: FoodImageAnalysis
    let mealType: MealType
    let progress: DailyNutritionProgress?
    let onDone: () -> Void

    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Meal logged")
                    .font(.headline)
                    .foregroundStyle(BeUTheme.primaryText)
                Text("\(mealType.title) saved with an estimated \(analysis.totalCalories) calories.")
                    .foregroundStyle(BeUTheme.secondaryText)
                if let progress {
                    Text("Calories consumed today: \(progress.consumedCalories)")
                        .font(.footnote)
                        .foregroundStyle(BeUTheme.secondaryText)
                    Text(progress.remainingCalories >= 0 ? "Calories remaining today: \(progress.remainingCalories)" : "Over by \(abs(progress.remainingCalories)) calories today")
                        .font(.footnote)
                        .foregroundStyle(BeUTheme.secondaryText)
                    Text(progress.remainingProteinGrams >= 0 ? "Protein remaining today: \(Int(progress.remainingProteinGrams.rounded()))g" : "Protein target exceeded by \(Int(abs(progress.remainingProteinGrams).rounded()))g")
                        .font(.footnote)
                        .foregroundStyle(BeUTheme.secondaryText)
                }
                Button("Back to Home", action: onDone)
                    .buttonStyle(BeUPrimaryButtonStyle())
            }
        }
        .tint(BeUTheme.primaryText)
    }
}

private struct MealLoggingDisclaimerFooter: View {
    let lines: [String]

    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(lines, id: \.self) { line in
                    Text(line)
                        .font(.footnote)
                        .foregroundStyle(BeUTheme.helperText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct MealInputFieldStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(BeUTheme.bodyFont)
            .foregroundColor(BeUTheme.inputText)
            .tint(BeUTheme.inputText)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(BeUTheme.inputBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(BeUTheme.border, lineWidth: 1)
                    )
            )
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
    }
}

private extension View {
    func mealInputStyle() -> some View {
        modifier(MealInputFieldStyleModifier())
    }
}

struct NutritionProfileSettingsView: View {
    let userId: String
    let currentProfile: UserNutritionProfile
    let onSave: (UserNutritionProfile) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var ageText: String
    @State private var sex: NutritionProfileSex
    @State private var heightText: String
    @State private var currentWeightText: String
    @State private var targetWeightText: String
    @State private var goalType: NutritionGoalType
    @State private var calorieTargetText: String
    @State private var proteinTargetText: String
    @State private var carbTargetText: String
    @State private var fatTargetText: String
    @State private var targetTimelineText: String
    @State private var errorMessage: String?

    init(userId: String, currentProfile: UserNutritionProfile, onSave: @escaping (UserNutritionProfile) -> Void) {
        self.userId = userId
        self.currentProfile = currentProfile
        self.onSave = onSave
        _ageText = State(initialValue: currentProfile.age.map(String.init) ?? "")
        _sex = State(initialValue: currentProfile.sex ?? .preferNotToSay)
        _heightText = State(initialValue: String(Int(currentProfile.heightCm.rounded())))
        _currentWeightText = State(initialValue: String(format: "%.1f", currentProfile.currentWeightKg))
        _targetWeightText = State(initialValue: currentProfile.targetWeightKg.map { String(format: "%.1f", $0) } ?? "")
        _goalType = State(initialValue: currentProfile.goalType)
        _calorieTargetText = State(initialValue: String(currentProfile.dailyCalorieTarget))
        _proteinTargetText = State(initialValue: String(currentProfile.dailyProteinTargetGrams))
        _carbTargetText = State(initialValue: currentProfile.dailyCarbTargetGrams.map(String.init) ?? "")
        _fatTargetText = State(initialValue: currentProfile.dailyFatTargetGrams.map(String.init) ?? "")
        _targetTimelineText = State(initialValue: currentProfile.targetTimeline ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("These targets are estimates and can be adjusted anytime.")
                        .font(BeUTheme.helperFont)
                        .foregroundColor(BeUTheme.mutedText)
                    OnboardingNumberField(title: "Age", text: $ageText)
                    Picker("Sex", selection: $sex) {
                        ForEach(NutritionProfileSex.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .beuSegmentedControlStyle()
                    OnboardingNumberField(title: "Height (cm)", text: $heightText)
                    OnboardingNumberField(title: "Current weight (kg)", text: $currentWeightText)
                    OnboardingNumberField(title: "Target weight (kg)", text: $targetWeightText)
                    Picker("Goal type", selection: $goalType) {
                        ForEach(NutritionGoalType.allCases) { goal in
                            Text(goal.title).tag(goal)
                        }
                    }
                    .beuMenuPickerStyle()
                    OnboardingTextField(title: "Target timeline", text: $targetTimelineText)
                    OnboardingNumberField(title: "Daily calorie target", text: $calorieTargetText)
                    OnboardingNumberField(title: "Daily protein target (g)", text: $proteinTargetText)
                    OnboardingNumberField(title: "Daily carb target (optional)", text: $carbTargetText)
                    OnboardingNumberField(title: "Daily fat target (optional)", text: $fatTargetText)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(BeUTheme.helperFont)
                            .foregroundColor(BeUTheme.lowStatus)
                    }

                    Button("Save changes") {
                        saveProfile()
                    }
                    .buttonStyle(BeUPrimaryButtonStyle())
                }
                .padding(24)
            }
            .background(BeUTheme.background.ignoresSafeArea())
            .navigationTitle("BeU Profile")
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(BeUTheme.primaryText)
    }

    private func saveProfile() {
        guard
            let height = Double(heightText),
            let currentWeight = Double(currentWeightText),
            let calories = Int(calorieTargetText),
            let protein = Int(proteinTargetText)
        else {
            errorMessage = "Please complete the required numeric fields."
            return
        }

        let minimum = NutritionTargetCalculator.minimumCalories(for: sex)
        guard calories >= minimum else {
            errorMessage = "Daily calories must be at least \(minimum) for this profile."
            return
        }

        let updated = UserNutritionProfile(
            userId: userId,
            age: Int(ageText),
            sex: sex,
            heightCm: height,
            currentWeightKg: currentWeight,
            targetWeightKg: Double(targetWeightText),
            goalType: goalType,
            dailyCalorieTarget: calories,
            dailyProteinTargetGrams: protein,
            dailyCarbTargetGrams: Int(carbTargetText),
            dailyFatTargetGrams: Int(fatTargetText),
            targetTimeline: targetTimelineText.isEmpty ? nil : targetTimelineText,
            createdAt: currentProfile.createdAt,
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
        onSave(updated)
        dismiss()
    }
}

struct ProfileGatewayView: View {
    @ObservedObject var nutritionViewModel: NutritionViewModel
    let onOpenTargets: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showSupplements = false
    @State private var showHealthHistory = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    identityCard
                    aboutYouSection
                    targetsSection

                    Text(BeUSafetyCopy.wellnessDisclaimer)
                        .font(BeUTheme.helperFont)
                        .foregroundColor(BeUTheme.mutedText)
                        .padding(.top, 8)
                }
                .padding(20)
            }
            .background(BeUTheme.background.ignoresSafeArea())
            .navigationTitle("BeU")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(BeUTheme.primaryText)
                }
            }
        }
        .sheet(isPresented: $showSupplements) {
            SupplementsView(nutritionViewModel: nutritionViewModel)
        }
        .sheet(isPresented: $showHealthHistory) {
            HealthHistoryView(nutritionViewModel: nutritionViewModel)
        }
    }

    private var identityCard: some View {
        BeUCard {
            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [BeUTheme.cardBackground, BeUTheme.accentSoft.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 56)
                    .overlay(
                        Image("BeULogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 52, height: 22)
                            .accessibilityLabel("BeU logo")
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("BeU Profile")
                        .font(BeUTheme.titleFont)
                        .foregroundColor(BeUTheme.primaryText)
                    Text("Member since \(memberSinceText)")
                        .font(BeUTheme.helperFont)
                        .foregroundColor(BeUTheme.secondaryText)
                }

                Spacer()
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [BeUTheme.cardBackground, BeUTheme.accentSoft.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    private var aboutYouSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("About you")
                .font(BeUTheme.sectionTitleFont)
                .foregroundColor(BeUTheme.primaryText)

            ProfileLinkRow(
                title: "Supplements",
                systemImage: "pills.fill",
                count: nutritionViewModel.supplementService.supplements.filter(\.isActive).count,
                action: { showSupplements = true }
            )

            ProfileLinkRow(
                title: "Health history",
                systemImage: "heart.text.square.fill",
                count: nutritionViewModel.healthHistoryService.conditions.filter(\.isActive).count,
                action: { showHealthHistory = true }
            )
        }
    }

    private var targetsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Targets & data")
                .font(BeUTheme.sectionTitleFont)
                .foregroundColor(BeUTheme.primaryText)

            BeUCard {
                VStack(spacing: 0) {
                    ProfileInsetRow(title: "Nutrition targets", action: onOpenTargets)
                    Divider().overlay(BeUTheme.divider)
                    ProfileInsetStaticRow(title: "Apple Health", subtitle: "Connected through HealthKit")
                    Divider().overlay(BeUTheme.divider)
                    ProfileInsetStaticRow(title: "Notifications", subtitle: "Coming soon")
                }
            }
        }
    }

    private var memberSinceText: String {
        let source = nutritionViewModel.profile?.createdAt ?? ISO8601DateFormatter().string(from: Date())
        let formatter = ISO8601DateFormatter()
        let output = DateFormatter()
        output.dateFormat = "MMMM yyyy"
        if let date = formatter.date(from: source) {
            return output.string(from: date)
        }
        return "recently"
    }
}

struct SupplementsView: View {
    @ObservedObject var nutritionViewModel: NutritionViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var editingSupplement: Supplement?
    @State private var isPresentingEditor = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        section(title: "Active", items: activeSupplements, opacity: 1)
                        section(title: "Paused", items: pausedSupplements, opacity: 0.55)

                        if activeSupplements.isEmpty && pausedSupplements.isEmpty {
                            emptyState
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(BeUTheme.helperFont)
                                .foregroundColor(BeUTheme.lowStatus)
                        }

                        Text("BeU only reminds you about supplements you've added. We don't recommend supplements, dosages, or interactions — please consult a healthcare professional for that.")
                            .font(BeUTheme.helperFont)
                            .foregroundColor(BeUTheme.mutedText)
                            .padding(.bottom, 110)
                    }
                    .padding(20)
                }
                .background(BeUTheme.background.ignoresSafeArea())

                Button {
                    editingSupplement = nil
                    isPresentingEditor = true
                } label: {
                    Text("Add supplement")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(BeUPrimaryButtonStyle())
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .shadow(color: BeUTheme.shadow, radius: 18, x: 0, y: 6)
            }
            .navigationTitle("Supplements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(BeUTheme.primaryText)
                }
            }
        }
        .sheet(isPresented: $isPresentingEditor) {
            SupplementEditorView(
                userId: nutritionViewModel.userId,
                supplement: editingSupplement,
                onSave: { supplement in
                    do {
                        try await nutritionViewModel.saveSupplement(supplement)
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                },
                onDelete: editingSupplement == nil ? nil : { supplement in
                    do {
                        try await nutritionViewModel.deleteSupplement(supplement)
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            )
        }
    }

    private var activeSupplements: [Supplement] {
        nutritionViewModel.supplementService.supplements.filter(\.isActive)
    }

    private var pausedSupplements: [Supplement] {
        nutritionViewModel.supplementService.supplements.filter { !$0.isActive }
    }

    @ViewBuilder
    private func section(title: String, items: [Supplement], opacity: Double) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(BeUTheme.sectionTitleFont)
                    .foregroundColor(BeUTheme.primaryText)

                ForEach(items) { supplement in
                    SupplementRowView(
                        supplement: supplement,
                        opacity: opacity,
                        onToggle: {
                            do {
                                try await nutritionViewModel.toggleSupplementActive(supplement)
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingSupplement = supplement
                        isPresentingEditor = true
                    }
                }
            }
            .opacity(opacity)
        }
    }

    private var emptyState: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .stroke(style: StrokeStyle(lineWidth: 1.25, dash: [6, 6]))
            .foregroundColor(BeUTheme.border)
            .frame(height: 180)
            .overlay {
                VStack(spacing: 10) {
                    Image(systemName: "pills.fill")
                        .font(.system(size: 24))
                        .foregroundColor(BeUTheme.accent)
                    Text("Nothing yet")
                        .font(BeUTheme.sectionTitleFont)
                        .foregroundColor(BeUTheme.primaryText)
                    Text("Add what you regularly take — we'll just remind you in your daily plan.")
                        .font(BeUTheme.helperFont)
                        .foregroundColor(BeUTheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }
    }
}

struct SupplementEditorView: View {
    let userId: String
    let supplement: Supplement?
    let onSave: (Supplement) async throws -> Void
    let onDelete: ((Supplement) async throws -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var dosage = ""
    @State private var frequency: SupplementFrequency = .daily
    @State private var timeOfDay: SupplementTime? = nil
    @State private var notes = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    LabeledInput(title: "Name") {
                        OnboardingTextField(title: "Name", text: $name)
                    }
                    LabeledInput(title: "Dosage") {
                        OnboardingTextField(title: "Dosage", text: $dosage)
                    }
                    LabeledInput(title: "Frequency") {
                        frequencyChips
                    }
                    LabeledInput(title: "Time of day") {
                        timeChips
                    }
                    LabeledInput(title: "Notes") {
                        textArea(text: $notes, placeholder: "Optional context")
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(BeUTheme.helperFont)
                            .foregroundColor(BeUTheme.lowStatus)
                    }

                    Button("Save") {
                        Task { await save() }
                    }
                    .buttonStyle(BeUPrimaryButtonStyle())
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if let supplement, let onDelete {
                        Button("Delete supplement") {
                            Task {
                                do {
                                    try await onDelete(supplement)
                                    dismiss()
                                } catch {
                                    errorMessage = error.localizedDescription
                                }
                            }
                        }
                        .font(BeUTheme.buttonFont)
                        .foregroundColor(BeUTheme.lowStatus)
                    }

                    Text("BeU does not provide medical or dosage advice. Please consult your healthcare professional before starting or stopping any supplement.")
                        .font(BeUTheme.helperFont)
                        .foregroundColor(BeUTheme.mutedText)
                }
                .padding(20)
            }
            .background(BeUTheme.background.ignoresSafeArea())
            .navigationTitle(supplement == nil ? "Add supplement" : "Edit supplement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .tint(BeUTheme.primaryText)
        .onAppear {
            if let supplement {
                name = supplement.name
                dosage = supplement.dosage ?? ""
                frequency = supplement.frequency
                timeOfDay = supplement.timeOfDay
                notes = supplement.notes ?? ""
            }
        }
    }

    private var frequencyChips: some View {
        HStack(spacing: 10) {
            ForEach(SupplementFrequency.allCases) { option in
                chip(title: option.title, isSelected: frequency == option) {
                    frequency = option
                }
            }
        }
    }

    private var timeChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                chip(title: "Any time", isSelected: timeOfDay == nil) {
                    timeOfDay = nil
                }
                ForEach(SupplementTime.allCases) { option in
                    chip(title: option.title, isSelected: timeOfDay == option) {
                        timeOfDay = option
                    }
                }
            }
        }
    }

    private func chip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(BeUTheme.helperFont.weight(.semibold))
                .foregroundColor(isSelected ? BeUTheme.buttonText : BeUTheme.primaryText)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isSelected ? BeUTheme.buttonBackground : BeUTheme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(BeUTheme.border, lineWidth: isSelected ? 0 : 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private func textArea(text: Binding<String>, placeholder: String) -> some View {
        BeUTextArea(placeholder: placeholder, text: text, minHeight: 110)
    }

    private func save() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let current = Date()
        let item = Supplement(
            id: supplement?.id ?? UUID().uuidString,
            userId: userId,
            name: trimmedName,
            dosage: dosage.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            frequency: frequency,
            timeOfDay: timeOfDay,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            isActive: supplement?.isActive ?? true,
            createdAt: supplement?.createdAt ?? current,
            updatedAt: current
        )

        do {
            try await onSave(item)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct HealthHistoryView: View {
    @ObservedObject var nutritionViewModel: NutritionViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTypes: Set<ConditionType> = []
    @State private var customName = ""
    @State private var globalNotes = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    whyWeAskCard

                    BeUCard {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(ConditionType.allCases) { conditionType in
                                conditionRow(for: conditionType)
                            }
                        }
                    }

                    if selectedTypes.contains(.other) {
                        LabeledInput(title: "Other condition") {
                            OnboardingTextField(title: "Custom name", text: $customName)
                        }
                    }

                    LabeledInput(title: "Notes") {
                        textArea(text: $globalNotes, placeholder: "Optional notes")
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(BeUTheme.helperFont)
                            .foregroundColor(BeUTheme.lowStatus)
                    }

                    Text("This helps BeU personalize general wellness guidance. It is not used for diagnosis or treatment. BeU does not replace medical advice.")
                        .font(BeUTheme.helperFont)
                        .foregroundColor(BeUTheme.mutedText)
                        .padding(.bottom, 18)
                }
                .padding(20)
            }
            .background(BeUTheme.background.ignoresSafeArea())
            .navigationTitle("Health history")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(BeUTheme.primaryText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .foregroundColor(BeUTheme.primaryText)
                }
            }
        }
        .tint(BeUTheme.primaryText)
        .onAppear(perform: preload)
    }

    private var whyWeAskCard: some View {
        BeUCard {
            HStack(alignment: .top, spacing: 14) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(BeUTheme.accent.opacity(0.1))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "heart.text.square.fill")
                            .foregroundColor(BeUTheme.accent)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text("Why we ask")
                        .font(BeUTheme.sectionTitleFont)
                        .foregroundColor(BeUTheme.primaryText)
                    Text("We adjust the wording of your daily plan — never medical advice. You can change or remove this anytime.")
                        .font(BeUTheme.bodyFont)
                        .foregroundColor(BeUTheme.secondaryText)
                }
            }
        }
    }

    private func conditionRow(for type: ConditionType) -> some View {
        Button {
            toggle(type)
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(isSelected(type) ? BeUTheme.accent : BeUTheme.border, lineWidth: 1.5)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(isSelected(type) ? BeUTheme.accent : .clear)
                    )
                    .frame(width: 22, height: 22)
                    .overlay {
                        if isSelected(type) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }

                Text(type.title)
                    .font(BeUTheme.bodyFont)
                    .foregroundColor(BeUTheme.primaryText)

                Spacer()
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private func isSelected(_ type: ConditionType) -> Bool {
        selectedTypes.contains(type)
    }

    private func toggle(_ type: ConditionType) {
        if type == .preferNotToSay {
            selectedTypes = isSelected(type) ? [] : [.preferNotToSay]
            return
        }

        if isSelected(type) {
            selectedTypes.remove(type)
        } else {
            selectedTypes.remove(.preferNotToSay)
            selectedTypes.insert(type)
        }
    }

    private func preload() {
        let activeConditions = nutritionViewModel.healthHistoryService.conditions.filter(\.isActive)
        selectedTypes = Set(activeConditions.map(\.conditionType))
        if let other = activeConditions.first(where: { $0.conditionType == .other }) {
            customName = other.customName ?? ""
        }
        globalNotes = activeConditions.first(where: { !($0.notes ?? "").isEmpty })?.notes ?? ""
    }

    private func save() async {
        do {
            let existing = nutritionViewModel.healthHistoryService.conditions
            let keepTypes = selectedTypes

            for condition in existing where !keepTypes.contains(condition.conditionType) {
                try await nutritionViewModel.deleteHealthCondition(condition)
            }

            for type in keepTypes {
                let existingCondition = existing.first(where: { $0.conditionType == type })
                let updated = HealthCondition(
                    id: existingCondition?.id ?? UUID().uuidString,
                    userId: nutritionViewModel.userId,
                    conditionType: type,
                    customName: type == .other ? customName.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty : nil,
                    notes: globalNotes.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    isActive: true,
                    createdAt: existingCondition?.createdAt ?? Date(),
                    updatedAt: Date()
                )
                try await nutritionViewModel.saveHealthCondition(updated)
            }

            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func textArea(text: Binding<String>, placeholder: String) -> some View {
        BeUTextArea(placeholder: placeholder, text: text, minHeight: 90)
    }
}

private struct ProfileLinkRow: View {
    let title: String
    let systemImage: String
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            BeUCard {
                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(BeUTheme.accent.opacity(0.1))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: systemImage)
                                .foregroundColor(BeUTheme.accent)
                        )

                    Text(title)
                        .font(BeUTheme.bodyFont.weight(.semibold))
                        .foregroundColor(BeUTheme.primaryText)

                    Spacer()

                    if count > 0 {
                        Text("\(count)")
                            .font(BeUTheme.helperFont.weight(.semibold))
                            .foregroundColor(BeUTheme.primaryText)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(BeUTheme.accent.opacity(0.14)))
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(BeUTheme.secondaryText)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct ProfileInsetRow: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(BeUTheme.bodyFont)
                    .foregroundColor(BeUTheme.primaryText)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(BeUTheme.secondaryText)
            }
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }
}

private struct ProfileInsetStaticRow: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(BeUTheme.bodyFont)
                    .foregroundColor(BeUTheme.primaryText)
                Text(subtitle)
                    .font(BeUTheme.helperFont)
                    .foregroundColor(BeUTheme.secondaryText)
            }
            Spacer()
        }
        .padding(.vertical, 14)
    }
}

private struct SupplementRowView: View {
    let supplement: Supplement
    let opacity: Double
    let onToggle: () async -> Void

    var body: some View {
        BeUCard {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(BeUTheme.accent.opacity(0.1))
                    .frame(width: 38, height: 38)
                    .overlay(
                        Image(systemName: "pills.fill")
                            .foregroundColor(BeUTheme.accent)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(supplement.name)
                        .font(BeUTheme.bodyFont.weight(.semibold))
                        .foregroundColor(BeUTheme.primaryText)

                    Text(metaLine)
                        .font(BeUTheme.helperFont)
                        .foregroundColor(BeUTheme.secondaryText)
                }

                Spacer()

                SupplementToggle(isOn: supplement.isActive) {
                    Task { await onToggle() }
                }
            }
        }
    }

    private var metaLine: String {
        [
            supplement.dosage,
            supplement.frequency.title,
            supplement.timeOfDay?.title
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }
}

private struct SupplementToggle: View {
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(isOn ? BeUTheme.accent : Color.black.opacity(0.08))
                .frame(width: 38, height: 22)
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 18, height: 18)
                        .padding(2)
                }
                .animation(.easeInOut(duration: 0.15), value: isOn)
        }
        .buttonStyle(.plain)
    }
}

private struct LabeledInput<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.8)
                .foregroundColor(BeUTheme.secondaryText)
            content
        }
    }
}

struct MealHistoryView: View {
    let meals: [MealLog]
    let onDelete: (MealLog) -> Void

    var body: some View {
        List {
            if meals.isEmpty {
                Text("No meals logged yet.")
                    .foregroundColor(BeUTheme.secondaryText)
            } else {
                ForEach(meals) { meal in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(meal.mealType.title)
                                .font(.headline)
                                .foregroundColor(BeUTheme.primaryText)
                            Spacer()
                            Text("\(meal.totalCalories) kcal")
                                .foregroundColor(BeUTheme.secondaryText)
                        }
                        Text(meal.items.map(\.name).joined(separator: ", "))
                            .font(BeUTheme.helperFont)
                            .foregroundColor(BeUTheme.secondaryText)
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            onDelete(meal)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("BeU Meal History")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(BeUTheme.background)
        .tint(BeUTheme.primaryText)
    }
}

struct WeeklyNutritionSummaryView: View {
    let summary: WeeklyNutritionSummary?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                DashboardCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Weekly Nutrition Summary")
                            .font(BeUTheme.titleFont)
                            .foregroundColor(BeUTheme.primaryText)
                        if let summary {
                            Text("\(summary.loggedDays) logged day\(summary.loggedDays == 1 ? "" : "s") • \(summary.totalMeals) meals")
                                .font(BeUTheme.bodyFont)
                                .foregroundColor(BeUTheme.secondaryText)
                            Text("Avg calories: \(summary.averageCalories) • Avg protein: \(Int(summary.averageProteinGrams.rounded()))g")
                                .font(BeUTheme.bodyFont)
                                .foregroundColor(BeUTheme.secondaryText)
                        } else {
                            Text("Weekly nutrition summary will appear after meals are logged.")
                                .font(BeUTheme.bodyFont)
                                .foregroundColor(BeUTheme.secondaryText)
                        }
                    }
                }

                if let summary {
                    DashboardCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Highlights")
                                .font(BeUTheme.sectionTitleFont)
                                .foregroundColor(BeUTheme.primaryText)
                            ForEach(summary.summaryLines, id: \.self) { line in
                                Text(line)
                                    .font(BeUTheme.helperFont)
                                    .foregroundColor(BeUTheme.secondaryText)
                            }
                        }
                    }

                    DashboardCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Daily breakdown")
                                .font(BeUTheme.sectionTitleFont)
                                .foregroundColor(BeUTheme.primaryText)
                            ForEach(summary.dailyBreakdown) { day in
                                HStack {
                                    Text(day.date)
                                        .font(BeUTheme.helperFont.weight(.semibold))
                                        .foregroundColor(BeUTheme.primaryText)
                                    Spacer()
                                    Text("\(day.consumedCalories) kcal")
                                        .font(BeUTheme.helperFont)
                                        .foregroundColor(BeUTheme.secondaryText)
                                    Text("\(Int(day.consumedProteinGrams.rounded()))g protein")
                                        .font(BeUTheme.helperFont)
                                        .foregroundColor(BeUTheme.secondaryText)
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("Weekly Nutrition")
        .navigationBarTitleDisplayMode(.inline)
        .background(BeUTheme.background.ignoresSafeArea())
        .tint(BeUTheme.primaryText)
    }
}

private struct WellnessFormCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        BeUCard {
            content
        }
    }
}

private struct DashboardCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        BeUCard {
            content
        }
    }
}

private struct OnboardingNumberField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        BeUNumberField(placeholder: title, text: $text)
    }
}

private struct OnboardingTextField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        BeUTextField(placeholder: title, text: $text)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

private struct NutritionMetricRow: View {
    let title: String
    let consumedText: String
    let remainingText: String
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(BeUTheme.bodyFont.weight(.semibold))
                    .foregroundColor(BeUTheme.primaryText)
                Spacer()
                Text(remainingText)
                    .font(BeUTheme.helperFont)
                    .foregroundColor(BeUTheme.mutedText)
            }
            Text(consumedText)
                .font(BeUTheme.helperFont)
                .foregroundColor(BeUTheme.secondaryText)
            ProgressView(value: progress, total: 1)
                .tint(BeUTheme.accent)
        }
    }
}

private struct MetricChip: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(BeUTheme.helperFont)
                .foregroundColor(BeUTheme.secondaryText)
            Text(value)
                .font(BeUTheme.sectionTitleFont)
                .foregroundColor(BeUTheme.primaryText)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BeUTheme.cardAltBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
