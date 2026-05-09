import PhotosUI
import SwiftUI
import UIKit

struct BeULogMealSheet: View {
    private enum SheetState {
        case chooser
        case describe
        case analyzing
        case review
        case estimate
        case success
    }

    let userId: String
    var dietPreference: String = "indian_vegetarian"
    let existingMeals: [MealLog]
    let waterLitres: Double
    let waterTargetLitres: Double
    let onLogWater: () -> Bool
    var backendIsWaking: Bool = false
    var initialEditingMeal: MealLog? = nil
    var initialSuggestedDescription: String? = nil
    var initialSuggestedMealType: MealType? = nil
    var calorieTarget: Int = 1700
    var proteinTarget: Int = 120
    var currentCaloriesConsumed: Int = 0
    var currentProteinConsumed: Double = 0
    var goalType: String = Goal.fatLoss.rawValue
    var healthConditions: [String] = []
    let onSave: (MealLog) -> Void
    let onUpdate: (MealLog) -> Void
    let onDelete: (MealLog) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @StateObject private var mealLoggingViewModel = MealLoggingViewModel()
    @State private var state: SheetState = .chooser
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var selectedMealType: MealType = .lunch
    @State private var typedMeal = ""
    @State private var typedMealError: String?
    @State private var analysis: FoodImageAnalysis?
    @State private var reviewItems: [DetectedFoodItem] = []
    @State private var displayedMeals: [MealLog] = []
    @State private var editingMeal: MealLog?
    @State private var pendingDeleteMeal: MealLog?
    @State private var isDeletingMeal = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var loadingMessage = "Estimating your meal..."

    private let analysisService = RealFoodImageAnalysisService()
    private let totalsService = NutritionLookupService()
    private let mealLogService = MealLogService()
    private let mealQualityService = MealQualityService()

    var body: some View {
        NavigationStack {
            ZStack {
                BeUTheme.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        content
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if state != .success {
                        Button(toolbarLeadingTitle) { handleLeadingAction() }
                            .foregroundColor(BeUTheme.primaryText)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $mealLoggingViewModel.isShowingCamera) {
            CameraPickerView { image in
                selectedImage = image
                Task { await analyzeImage(image) }
            }
        }
        .photosPicker(isPresented: $mealLoggingViewModel.isShowingGallery, selection: $selectedPhotoItem, matching: .images)
        .alert(
            "Camera access is disabled",
            isPresented: $mealLoggingViewModel.cameraPermissionDenied
        ) {
            Button("Open Settings") { mealLoggingViewModel.openSettings() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enable it in Settings to take meal photos.")
        }
        .alert(
            "Log meal",
            isPresented: Binding(
                get: { errorMessage != nil || mealLoggingViewModel.errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        errorMessage = nil
                        mealLoggingViewModel.errorMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? mealLoggingViewModel.errorMessage ?? "")
        }
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item else { return }
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    errorMessage = "The selected image could not be read."
                    return
                }
                selectedImage = image
                await analyzeImage(image)
            }
        }
        .onAppear {
            displayedMeals = sortedMeals(existingMeals)
            if let initialEditingMeal, editingMeal?.id != initialEditingMeal.id {
                beginEditing(initialEditingMeal)
            } else if let initialSuggestedDescription, typedMeal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                typedMeal = initialSuggestedDescription
                if let initialSuggestedMealType {
                    selectedMealType = initialSuggestedMealType
                }
                state = .describe
            }
        }
        .onChange(of: existingMeals) { _, meals in
            displayedMeals = sortedMeals(meals)
        }
        .confirmationDialog(
            "Delete meal?",
            isPresented: Binding(
                get: { pendingDeleteMeal != nil },
                set: { if !$0 { pendingDeleteMeal = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                guard let pendingDeleteMeal else { return }
                Task { await deleteMeal(pendingDeleteMeal) }
            }
            .disabled(isDeletingMeal)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the meal and update your daily calories and macros.")
        }
        .overlay(alignment: .bottom) {
            if let successMessage {
                Text(successMessage)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule(style: .continuous)
                            .fill(BeUTheme.primaryText)
                    )
                    .padding(.bottom, 24)
                    .transition(.opacity)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .chooser:
            MealLogEntryView(
                meals: displayedMeals,
                waterLitres: waterLitres,
                waterTargetLitres: waterTargetLitres,
                calorieTarget: calorieTarget,
                proteinTarget: proteinTarget,
                goalType: goalType,
                healthConditions: healthConditions,
                onLogWater: onLogWater,
                onTakePhoto: mealLoggingViewModel.takePhotoTapped,
                onDescribe: {
                    resetDraftForNewMeal()
                    typedMealError = nil
                    state = .describe
                },
                onChooseFromLibrary: mealLoggingViewModel.uploadFromGalleryTapped,
                onEditMeal: beginEditing,
                onDeleteMeal: { pendingDeleteMeal = $0 }
            )
        case .describe:
            DescribeMealView(
                description: $typedMeal,
                selectedMealType: $selectedMealType,
                errorMessage: typedMealError,
                onAnalyze: { Task { await analyzeTextMeal() } },
                onBack: { state = .chooser }
            )
        case .analyzing:
            MealAnalysisLoadingView(message: loadingMessage)
        case .review:
            if let analysis {
                BeUDetectedFoodReviewView(
                    title: editingMeal == nil ? "Review what BeU found" : "Edit meal",
                    helperText: editingMeal == nil
                        ? "These are estimates based on your description. Edit anything that looks off."
                        : "Update the items, portions, and macros before saving your changes.",
                    analysis: analysis,
                    selectedMealType: $selectedMealType,
                    items: $reviewItems,
                    onAddItem: addReviewItem,
                    onConfirm: { Task { await confirmReviewedItems() } }
                )
            }
        case .estimate:
            if let analysis {
                BeUMacroEstimateView(
                    analysis: analysis,
                    mealQuality: mealQualityResult,
                    selectedMealType: $selectedMealType,
                    onLogMeal: saveMeal
                )
            }
        case .success:
            SuccessStateView(onDone: { dismiss() })
        }
    }

    private var toolbarLeadingTitle: String {
        switch state {
        case .chooser:
            return "Close"
        case .describe, .review, .estimate, .analyzing:
            return "Back"
        case .success:
            return ""
        }
    }

    private func handleLeadingAction() {
        switch state {
        case .chooser:
            dismiss()
        case .describe:
            state = .chooser
        case .review:
            if editingMeal != nil {
                state = .chooser
            } else {
                state = analysis?.inputType == "text" ? .describe : .chooser
            }
        case .estimate:
            state = .review
        case .analyzing:
            state = analysis == nil ? .chooser : .review
        case .success:
            break
        }
    }

    private func analyzeImage(_ image: UIImage) async {
        loadingMessage = backendIsWaking
            ? "Waking BeU analysis engine. This may take a few seconds."
            : "Estimating your meal..."
        state = .analyzing
        errorMessage = nil

        do {
            let loaded = try await analysisService.analyzeFoodImage(image, userId: userId)
            apply(loaded)
        } catch {
            errorMessage = "Meal analysis failed. Please try again."
            state = .chooser
        }
    }

    private func analyzeTextMeal() async {
        let trimmed = typedMeal.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 5 else {
            typedMealError = "Describe what you ate so BeU can estimate it."
            return
        }

        typedMealError = nil
        loadingMessage = backendIsWaking
            ? "Waking BeU analysis engine. This may take a few seconds."
            : "Estimating your meal..."
        state = .analyzing
        errorMessage = nil

        do {
            let loaded = try await analysisService.analyzeFoodText(
                trimmed,
                userId: userId,
                mealType: selectedMealType,
                dietPreference: dietPreference
            )
            apply(loaded)
        } catch let apiError as APIError {
            errorMessage = apiError.errorDescription ?? "Meal analysis is unavailable right now. Please try again."
            state = .describe
        } catch {
            errorMessage = "We couldn’t estimate this meal. Try adding more detail or log items manually."
            state = .describe
        }
    }

    private func confirmReviewedItems() async {
        guard var current = analysis else { return }
        guard reviewItems.isEmpty == false else {
            errorMessage = "Add at least one item before saving."
            state = .review
            return
        }
        let sanitizedItems = reviewItems.map { item in
            DetectedFoodItem(
                id: item.id,
                name: item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Custom item" : item.name.trimmingCharacters(in: .whitespacesAndNewlines),
                estimatedPortion: item.estimatedPortion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Estimated serving" : item.estimatedPortion.trimmingCharacters(in: .whitespacesAndNewlines),
                quantityGrams: item.quantityGrams,
                confidence: item.confidence,
                calories: max(0, item.calories),
                proteinGrams: max(0, item.proteinGrams),
                carbsGrams: max(0, item.carbsGrams),
                fatGrams: max(0, item.fatGrams),
                userConfirmed: true
            )
        }

        loadingMessage = backendIsWaking
            ? "Waking BeU analysis engine. This may take a few seconds."
            : "Estimating your meal..."
        state = .analyzing

        do {
            current = try await analysisService.updateDetectedItems(
                sanitizedItems,
                userId: userId,
                imageLocalPath: current.imageLocalPath,
                analysisId: current.id
            )
            analysis = current
            reviewItems = current.detectedItems
            state = .estimate
        } catch {
            errorMessage = "We couldn’t update this meal estimate. Please try again."
            state = .review
        }
    }

    private func addReviewItem() {
        reviewItems.append(
            DetectedFoodItem(
                id: UUID().uuidString,
                name: "",
                estimatedPortion: "1 serving",
                quantityGrams: 100,
                confidence: "low",
                calories: 0,
                proteinGrams: 0,
                carbsGrams: 0,
                fatGrams: 0,
                userConfirmed: false
            )
        )
    }

    private func beginEditing(_ meal: MealLog) {
        editingMeal = meal
        selectedMealType = meal.mealType
        typedMeal = meal.originalInput ?? meal.items.map(\.name).joined(separator: ", ")
        selectedImage = nil
        analysis = FoodImageAnalysis(
            id: meal.id,
            userId: meal.userId,
            inputType: meal.source == "text" ? "text" : "image",
            originalDescription: meal.originalInput,
            imageLocalPath: meal.imageLocalPath,
            imageRemoteUrl: nil,
            detectedItems: meal.items,
            totalCalories: meal.totalCalories,
            totalProteinGrams: meal.totalProteinGrams,
            totalCarbsGrams: meal.totalCarbsGrams,
            totalFatGrams: meal.totalFatGrams,
            confidence: "medium",
            notes: [
                "Nutrition values are estimates based on your confirmed meal items.",
                "Edit anything that looks off before saving."
            ],
            createdAt: meal.createdAt
        )
        reviewItems = meal.items
        state = .review
    }

    private func apply(_ loaded: FoodImageAnalysis) {
        analysis = loaded
        reviewItems = loaded.detectedItems
        state = .review
    }

    private func saveMeal() {
        guard let analysis else { return }
        guard reviewItems.isEmpty == false else {
            errorMessage = "Add at least one item before saving."
            state = .review
            return
        }

        let imagePath: String?
        if let selectedImage, editingMeal == nil {
            imagePath = try? mealLogService.persistImage(selectedImage)
        } else {
            imagePath = editingMeal?.imageLocalPath ?? analysis.imageLocalPath
        }

        let now = ISO8601DateFormatter().string(from: Date())
        let totals = totalsService.totals(for: reviewItems)
        let meal = MealLog(
            id: editingMeal?.id ?? UUID().uuidString,
            userId: userId,
            date: editingMeal?.date ?? ISODateOnlyFormatter.shared.string(from: Date()),
            dayOfWeek: editingMeal?.dayOfWeek ?? MealLog.dayOfWeekString(from: ISODateOnlyFormatter.shared.string(from: Date())),
            mealType: selectedMealType,
            loggedAt: editingMeal?.loggedAt ?? now,
            source: editingMeal?.source ?? analysis.inputType,
            originalInput: analysis.originalDescription ?? (typedMeal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : typedMeal.trimmingCharacters(in: .whitespacesAndNewlines)),
            imageLocalPath: imagePath,
            items: reviewItems,
            totalCalories: totals.calories,
            totalProteinGrams: totals.proteinGrams,
            totalCarbsGrams: totals.carbsGrams,
            totalFatGrams: totals.fatGrams,
            createdAt: editingMeal?.createdAt ?? now,
            updatedAt: now
        )

        if editingMeal != nil {
            onUpdate(meal)
            displayedMeals = sortedMeals(displayedMeals.filter { $0.id != meal.id } + [meal])
            resetDraftForNewMeal()
            state = .chooser
        } else {
            onSave(meal)
            displayedMeals = sortedMeals(displayedMeals + [meal])
            resetDraftForNewMeal()
            state = .success
        }
    }

    private func deleteMeal(_ meal: MealLog) async {
        let mealId = meal.id
        guard isDeletingMeal == false else { return }

        await MainActor.run {
            isDeletingMeal = true
            successMessage = nil
        }

        print("[MealDelete] Delete requested:", mealId)
        let deleted = await onDelete(meal)

        await MainActor.run {
            if deleted {
                clearDeletedMealState(mealId: mealId)
                displayedMeals = sortedMeals(existingMeals.filter { $0.id != mealId })
                pendingDeleteMeal = nil
                isDeletingMeal = false
                successMessage = "Meal deleted"
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    await MainActor.run {
                        if self.successMessage == "Meal deleted" {
                            self.successMessage = nil
                        }
                    }
                }
            } else {
                errorMessage = "Could not delete meal. Please try again."
                pendingDeleteMeal = nil
                isDeletingMeal = false
            }
        }
    }

    private func clearDeletedMealState(mealId: String) {
        editingMeal = nil
        if analysis?.id == mealId {
            analysis = nil
        }
        reviewItems = []
        typedMeal = ""
        typedMealError = nil
        selectedImage = nil
        selectedPhotoItem = nil
        if state != .chooser {
            state = .chooser
        }
    }

    private func resetDraftForNewMeal() {
        editingMeal = nil
        typedMeal = ""
        typedMealError = nil
        analysis = nil
        reviewItems = []
        errorMessage = nil
        selectedMealType = .lunch
        selectedImage = nil
        selectedPhotoItem = nil
    }

    private var mealQualityResult: MealQualityResult? {
        let baseCaloriesConsumed = max(currentCaloriesConsumed - (editingMeal?.totalCalories ?? 0), 0)
        let baseProteinConsumed = max(currentProteinConsumed - (editingMeal?.totalProteinGrams ?? 0), 0)
        let remainingCalories = max(calorieTarget - baseCaloriesConsumed, 0)
        let remainingProtein = max(Double(proteinTarget) - baseProteinConsumed, 0)

        return mealQualityService.scoreMeal(
            items: reviewItems,
            context: MealQualityContext(
                mealType: selectedMealType,
                goalType: goalType,
                calorieTarget: calorieTarget,
                proteinTarget: proteinTarget,
                caloriesRemaining: remainingCalories,
                proteinRemaining: remainingProtein,
                healthConditions: healthConditions
            )
        )
    }

    private func sortedMeals(_ meals: [MealLog]) -> [MealLog] {
        let order: [MealType: Int] = [.breakfast: 0, .lunch: 1, .dinner: 2, .snack: 3]
        return meals.sorted { lhs, rhs in
            let lhsOrder = order[lhs.mealType] ?? 99
            let rhsOrder = order[rhs.mealType] ?? 99
            if lhsOrder != rhsOrder {
                return lhsOrder < rhsOrder
            }
            return lhs.loggedAt < rhs.loggedAt
        }
    }
}

private struct MealLogEntryView: View {
    let meals: [MealLog]
    let waterLitres: Double
    let waterTargetLitres: Double
    let calorieTarget: Int
    let proteinTarget: Int
    let goalType: String
    let healthConditions: [String]
    let onLogWater: () -> Bool
    let onTakePhoto: () -> Void
    let onDescribe: () -> Void
    let onChooseFromLibrary: () -> Void
    let onEditMeal: (MealLog) -> Void
    let onDeleteMeal: (MealLog) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Log a meal")
                    .font(BeUTheme.titleFont)
                    .foregroundColor(BeUTheme.primaryText)
                Text("Add a meal or review what you’ve already logged today.")
                    .font(.system(size: 14))
                    .foregroundColor(BeUTheme.secondaryText)
            }

            OptionCard(
                icon: "camera",
                title: "Take a photo",
                subtitle: "Snap your plate and BeU will estimate the meal.",
                badge: nil,
                onTap: onTakePhoto
            )

            OptionCard(
                icon: "pencil.and.outline",
                title: "Describe in words",
                subtitle: "Type or dictate what you ate.",
                badge: "Good for quick logs",
                onTap: onDescribe
            )

            OptionCard(
                icon: "photo",
                title: "Choose from library",
                subtitle: "Upload an existing food photo.",
                badge: nil,
                onTap: onChooseFromLibrary
            )

            LogMealWaterCard(
                litres: waterLitres,
                target: waterTargetLitres,
                onTap: onLogWater
            )

            PreviouslyLoggedMealsSection(
                meals: meals,
                calorieTarget: calorieTarget,
                proteinTarget: proteinTarget,
                goalType: goalType,
                healthConditions: healthConditions,
                onEditMeal: onEditMeal,
                onDeleteMeal: onDeleteMeal
            )

            Spacer(minLength: 24)

            Text("BeU provides general wellness guidance only. Nutrition estimates can be imperfect, so please review before logging.")
                .font(BeUTheme.helperFont)
                .foregroundColor(BeUTheme.secondaryText)
        }
    }
}

private struct LogMealWaterCard: View {
    let litres: Double
    let target: Double
    let onTap: () -> Bool

    var body: some View {
        Button(action: {
            _ = onTap()
        }) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(BeUTheme.accent.opacity(0.12))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "drop.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(BeUTheme.accent)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Log water")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(BeUTheme.primaryText)
                    Text(waterSubtitle)
                        .font(.system(size: 10.5, weight: .medium))
                        .monospacedDigit()
                        .foregroundColor(BeUTheme.tertiaryText)
                }

                Spacer()

                Text("+100 ml")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(BeUTheme.primaryText)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(BeUTheme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(BeUTheme.hairline, lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var waterSubtitle: String {
        let percent = min(100, Int((litres / max(target, 0.1)) * 100))
        if litres < 1 {
            return String(format: "%.2f/%.1fL · %d%%", litres, target, percent)
        }
        return String(format: "%.1f/%.1fL · %d%%", litres, target, percent)
    }
}

private struct DescribeMealView: View {
    @Binding var description: String
    @Binding var selectedMealType: MealType
    let errorMessage: String?
    let onAnalyze: () -> Void
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Describe your meal")
                .font(BeUTheme.titleFont)
                .foregroundColor(BeUTheme.primaryText)

            Text("Tell BeU what you ate. Include portions if you can.")
                .font(.system(size: 14))
                .foregroundColor(BeUTheme.secondaryText)

            BeUTextArea(
                placeholder: "Example: 2 rotis, paneer bhurji, curd and salad",
                text: $description,
                minHeight: 160
            )

            if let errorMessage {
                Text(errorMessage)
                    .font(BeUTheme.helperFont)
                    .foregroundColor(BeUTheme.lowStatus)
            }

            BeUMealTypeSelector(selectedMealType: $selectedMealType)

            Button(action: onAnalyze) {
                Text("Analyze meal")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(description.trimmingCharacters(in: .whitespacesAndNewlines).count >= 5 ? BeUTheme.primaryText : Color.black.opacity(0.12))
                    )
            }
            .buttonStyle(.plain)
            .disabled(description.trimmingCharacters(in: .whitespacesAndNewlines).count < 5)

            Button("Back", action: onBack)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(BeUTheme.primaryText)

            Text(BeUSafetyCopy.wellnessDisclaimer)
                .font(BeUTheme.helperFont)
                .foregroundColor(BeUTheme.secondaryText)
        }
    }
}

private struct MealAnalysisLoadingView: View {
    let message: String

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 80)
            Circle()
                .fill(BeUTheme.accent.opacity(0.18))
                .frame(width: 88, height: 88)
                .overlay(
                    Image(systemName: "sparkles")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(BeUTheme.accent)
                )
            Text(message)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(BeUTheme.primaryText)
            Text("These are estimates. You’ll review items before anything is logged.")
                .font(.system(size: 13.5))
                .foregroundColor(BeUTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 520)
    }
}

private struct BeUDetectedFoodReviewView: View {
    let title: String
    let helperText: String
    let analysis: FoodImageAnalysis
    @Binding var selectedMealType: MealType
    @Binding var items: [DetectedFoodItem]
    let onAddItem: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(BeUTheme.titleFont)
                .foregroundColor(BeUTheme.primaryText)

            Text(helperText)
                .font(.system(size: 14))
                .foregroundColor(BeUTheme.secondaryText)

            if let description = analysis.originalDescription, analysis.inputType == "text" {
                BeUCard {
                    VStack(alignment: .leading, spacing: 8) {
                        BeUKicker(text: "You said")
                        Text(description)
                            .font(.system(size: 14))
                            .foregroundColor(BeUTheme.primaryText)
                    }
                }
            }

            BeUMealTypeSelector(selectedMealType: $selectedMealType)

            VStack(spacing: 12) {
                ForEach(items, id: \.id) { item in
                    if let binding = binding(for: item.id) {
                        EditableDetectedFoodRow(
                            item: binding,
                            onRemove: { items.removeAll { $0.id == item.id } }
                        )
                    }
                }
            }

            Button(action: onAddItem) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text("Add missing item")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(BeUTheme.primaryText)
            }
            .buttonStyle(.plain)

            Button(action: onConfirm) {
                Text("Confirm items")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(BeUTheme.primaryText)
                    )
            }
            .buttonStyle(.plain)

            Text(BeUSafetyCopy.wellnessDisclaimer)
                .font(BeUTheme.helperFont)
                .foregroundColor(BeUTheme.secondaryText)
        }
    }

    private func binding(for itemID: String) -> Binding<DetectedFoodItem>? {
        guard items.contains(where: { $0.id == itemID }) else {
            return nil
        }

        return Binding(
            get: {
                guard let liveIndex = items.firstIndex(where: { $0.id == itemID }) else {
                    return DetectedFoodItem(
                        id: itemID,
                        name: "",
                        estimatedPortion: "1 serving",
                        quantityGrams: 0,
                        confidence: "low",
                        calories: 0,
                        proteinGrams: 0,
                        carbsGrams: 0,
                        fatGrams: 0,
                        userConfirmed: false
                    )
                }
                return items[liveIndex]
            },
            set: { newValue in
                guard let liveIndex = items.firstIndex(where: { $0.id == itemID }) else { return }
                items[liveIndex] = newValue
            }
        )
    }
}

private struct PreviouslyLoggedMealsSection: View {
    let meals: [MealLog]
    let calorieTarget: Int
    let proteinTarget: Int
    let goalType: String
    let healthConditions: [String]
    let onEditMeal: (MealLog) -> Void
    let onDeleteMeal: (MealLog) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Previously Logged Meals")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(BeUTheme.primaryText)

            if meals.isEmpty {
                BeUCard {
                    Text("No meals logged yet today.")
                        .font(.system(size: 14))
                        .foregroundColor(BeUTheme.secondaryText)
                }
            } else {
                VStack(spacing: 12) {
                    ForEach(meals) { meal in
                        PreviouslyLoggedMealCard(
                            meal: meal,
                            quality: MealQualityService().scoreMeal(
                                items: meal.items,
                                context: MealQualityContext(
                                    mealType: meal.mealType,
                                    goalType: goalType,
                                    calorieTarget: calorieTarget,
                                    proteinTarget: proteinTarget,
                                    caloriesRemaining: nil,
                                    proteinRemaining: nil,
                                    healthConditions: healthConditions
                                )
                            ),
                            onEdit: { onEditMeal(meal) },
                            onDelete: { onDeleteMeal(meal) }
                        )
                    }
                }
            }
        }
    }
}

private struct PreviouslyLoggedMealCard: View {
    let meal: MealLog
    let quality: MealQualityResult?
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var showingQuality = false

    var body: some View {
        BeUCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(meal.mealType.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(BeUTheme.primaryText)
                    Spacer()
                    Text(timeText)
                        .font(BeUTheme.helperFont)
                        .foregroundColor(BeUTheme.secondaryText)
                }

                Text(mealSummary)
                    .font(.system(size: 14))
                    .foregroundColor(BeUTheme.secondaryText)
                    .lineLimit(2)

                HStack(spacing: 12) {
                    macroText("\(meal.totalCalories) kcal")
                    macroText("\(Int(meal.totalProteinGrams.rounded()))g protein")
                    macroText("\(Int(meal.totalCarbsGrams.rounded()))g carbs")
                    macroText("\(Int(meal.totalFatGrams.rounded()))g fat")
                }

                if let quality {
                    Button {
                        showingQuality = true
                    } label: {
                        MealQualityCompact(result: quality)
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 16) {
                    Button("Edit", action: onEdit)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(BeUTheme.primaryText)
                        .buttonStyle(.plain)
                    Button("Delete", action: onDelete)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(BeUTheme.lowStatus)
                        .buttonStyle(.plain)
                }
            }
        }
        .sheet(isPresented: $showingQuality) {
            if let quality {
                MealQualityCard(result: quality)
                    .padding(16)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private var mealSummary: String {
        let names = meal.items.map(\.name).filter { !$0.isEmpty }
        return names.isEmpty ? "Meal items not available" : names.joined(separator: ", ")
    }

    private var timeText: String {
        let iso = ISO8601DateFormatter()
        guard let date = iso.date(from: meal.loggedAt) ?? iso.date(from: meal.createdAt) else {
            return "Logged today"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func macroText(_ value: String) -> some View {
        Text(value)
            .font(BeUTheme.helperFont)
            .foregroundColor(BeUTheme.secondaryText)
    }
}

private struct BeUMacroEstimateView: View {
    let analysis: FoodImageAnalysis
    let mealQuality: MealQualityResult?
    @Binding var selectedMealType: MealType
    let onLogMeal: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Estimated nutrition")
                .font(BeUTheme.titleFont)
                .foregroundColor(BeUTheme.primaryText)

            BeUCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        macroBlock("Calories", "\(analysis.totalCalories)")
                        macroBlock("Protein", "\(Int(analysis.totalProteinGrams.rounded()))g")
                    }
                    HStack(spacing: 12) {
                        macroBlock("Carbs", "\(Int(analysis.totalCarbsGrams.rounded()))g")
                        macroBlock("Fat", "\(Int(analysis.totalFatGrams.rounded()))g")
                    }
                }
            }

            if let mealQuality {
                MealQualityCard(result: mealQuality)
            }

            BeUMealTypeSelector(selectedMealType: $selectedMealType)

            Button(action: onLogMeal) {
                Text("Log meal")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(BeUTheme.primaryText)
                    )
            }
            .buttonStyle(.plain)

            Text("These numbers are estimates. Confirmed items will be saved to your daily targets.")
                .font(BeUTheme.helperFont)
                .foregroundColor(BeUTheme.secondaryText)

            Text(BeUSafetyCopy.wellnessDisclaimer)
                .font(BeUTheme.helperFont)
                .foregroundColor(BeUTheme.secondaryText)
        }
    }

    private func macroBlock(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(BeUTheme.kickerFont)
                .foregroundColor(BeUTheme.tertiaryText)
            Text(value)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(BeUTheme.primaryText)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct BeUMealTypeSelector: View {
    @Binding var selectedMealType: MealType

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            BeUKicker(text: "Meal type")
            HStack(spacing: 8) {
                ForEach(MealType.allCases) { type in
                    Button {
                        selectedMealType = type
                    } label: {
                        Text(type.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(selectedMealType == type ? .white : BeUTheme.primaryText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(selectedMealType == type ? BeUTheme.primaryText : BeUTheme.cardBackground)
                                    .overlay(
                                        Capsule(style: .continuous)
                                            .stroke(BeUTheme.hairline, lineWidth: selectedMealType == type ? 0 : 0.5)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct EditableDetectedFoodRow: View {
    @Binding var item: DetectedFoodItem
    let onRemove: () -> Void

    var body: some View {
        BeUCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        BeUTextField(
                            placeholder: "Food name",
                            text: $item.name,
                            autocapitalization: .words
                        )

                        HStack(spacing: 8) {
                            BeUTextField(placeholder: "Portion", text: $item.estimatedPortion)
                            BeUNumberField(
                                placeholder: "Grams",
                                text: Binding(
                                    get: { item.quantityGrams.map { String(Int($0.rounded())) } ?? "" },
                                    set: { item.quantityGrams = Double($0) }
                                ),
                                keyboardType: .numberPad
                            )
                            .frame(width: 96)
                        }
                    }

                    Spacer()

                    Button(role: .destructive, action: onRemove) {
                        Image(systemName: "trash")
                            .foregroundColor(BeUTheme.lowStatus)
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 8) {
                    macroField("Calories", text: Binding(
                        get: { String(item.calories) },
                        set: { item.calories = Int($0) ?? item.calories }
                    ))
                    macroField("Protein", text: Binding(
                        get: { String(format: "%.1f", item.proteinGrams) },
                        set: { item.proteinGrams = Double($0) ?? item.proteinGrams }
                    ))
                    macroField("Carbs", text: Binding(
                        get: { String(format: "%.1f", item.carbsGrams) },
                        set: { item.carbsGrams = Double($0) ?? item.carbsGrams }
                    ))
                    macroField("Fat", text: Binding(
                        get: { String(format: "%.1f", item.fatGrams) },
                        set: { item.fatGrams = Double($0) ?? item.fatGrams }
                    ))
                }

                HStack {
                    Text("Confidence: \(item.confidence.capitalized)")
                        .font(BeUTheme.helperFont)
                        .foregroundColor(BeUTheme.secondaryText)
                    Spacer()
                    HStack(spacing: 8) {
                        Text("Confirmed")
                            .font(BeUTheme.helperFont)
                            .foregroundColor(BeUTheme.secondaryText)
                        Toggle("", isOn: $item.userConfirmed)
                            .labelsHidden()
                            .tint(BeUTheme.accent)
                    }
                }
            }
        }
    }

    private func macroField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(BeUTheme.kickerFont)
                .foregroundColor(BeUTheme.secondaryText)
            BeUNumberField(placeholder: label, text: text)
                .keyboardType(.decimalPad)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct OptionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let badge: String?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(BeUTheme.cardAltBackground)
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(BeUTheme.accent)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(BeUTheme.primaryText)
                        if let badge {
                            Text(badge)
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundColor(BeUTheme.accent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(BeUTheme.accent.opacity(0.12))
                                )
                        }
                    }
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(BeUTheme.secondaryText)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(BeUTheme.tertiaryText)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(BeUTheme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(BeUTheme.hairline, lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct SuccessStateView: View {
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 80)
            Circle()
                .fill(BeUTheme.ok)
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.white)
                )
            Text("Logged")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(BeUTheme.primaryText)
            Text("Your daily targets just updated.")
                .font(.system(size: 13.5))
                .foregroundColor(BeUTheme.secondaryText)
            Button("Back", action: onDone)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(BeUTheme.primaryText)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    Capsule(style: .continuous)
                        .fill(BeUTheme.cardBackground)
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(BeUTheme.hairline, lineWidth: 0.5)
                        )
                )
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 520)
    }
}
