import SwiftUI

enum BeUOnboardingMode {
    case firstRun
    case reviewBaseline
}

private enum BeUBaselineStep: Int, CaseIterable {
    case welcome
    case body
    case medical
    case supplements
    case summary
}

struct BeUOnboardingFlowView: View {
    let mode: BeUOnboardingMode
    let initialBaseline: Baseline
    let onComplete: (Baseline) -> Void
    let onCancel: () -> Void

    @State private var step: BeUBaselineStep
    @State private var draft: Baseline
    @State private var editingSupplement: Supplement?
    @State private var showingSupplementEditor = false

    init(
        mode: BeUOnboardingMode,
        initialBaseline: Baseline,
        onComplete: @escaping (Baseline) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.mode = mode
        self.initialBaseline = initialBaseline
        self.onComplete = onComplete
        self.onCancel = onCancel
        _draft = State(initialValue: initialBaseline)
        _step = State(initialValue: mode == .firstRun ? .welcome : .body)
    }

    var body: some View {
        currentStepView
            .sheet(isPresented: $showingSupplementEditor) {
                BeUSupplementEditorSheet(existing: editingSupplement) { supplement in
                    if let index = draft.supplements.firstIndex(where: { $0.id == supplement.id }) {
                        draft.supplements[index] = supplement
                    } else {
                        draft.supplements.append(supplement)
                    }
                    editingSupplement = nil
                    showingSupplementEditor = false
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
    }

    @ViewBuilder
    private var currentStepView: some View {
        switch step {
        case .welcome:
            BeUWelcomeView(
                onContinue: { step = .body },
                onBack: onCancel
            )
        case .body:
            BeUBodyProfileView(
                baseline: $draft,
                canGoBack: mode == .reviewBaseline ? true : step != .welcome,
                onBack: moveBack,
                onContinue: { step = .medical }
            )
        case .medical:
            BeUMedicalHistoryView(
                baseline: $draft,
                onBack: moveBack,
                onContinue: { step = .supplements }
            )
        case .supplements:
            BeUBaselineSupplementsView(
                baseline: $draft,
                onBack: moveBack,
                onContinue: { step = .summary },
                onAdd: {
                    editingSupplement = nil
                    showingSupplementEditor = true
                },
                onEdit: { supplement in
                    editingSupplement = supplement
                    showingSupplementEditor = true
                }
            )
        case .summary:
            BeUBaselineSummaryView(
                baseline: draft,
                onBack: moveBack,
                onConfirm: { onComplete(draft) }
            )
        }
    }

    private func moveBack() {
        switch step {
        case .welcome:
            onCancel()
        case .body:
            if mode == .reviewBaseline {
                onCancel()
            } else {
                step = .welcome
            }
        case .medical:
            step = .body
        case .supplements:
            step = .medical
        case .summary:
            step = .supplements
        }
    }
}

private struct BeUWelcomeView: View {
    let onContinue: () -> Void
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(BeUTheme.primaryText)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(BeUTheme.cardBackground))
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)

            Spacer()

            VStack(spacing: 22) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [BeUTheme.accent, BeUTheme.accentSoft],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 88, height: 88)
                    .shadow(color: BeUTheme.accent.opacity(0.35), radius: 40, x: 0, y: 12)
                    .overlay(
                        Image("BeULogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 62, height: 32)
                            .accessibilityLabel("BeU logo")
                    )

                VStack(spacing: 14) {
                    BeUKicker(text: "One-time setup · ~3 min")

                    Text("Build your\nBeU baseline")
                        .font(.system(size: 38, weight: .light, design: .serif).italic())
                        .tracking(-1.0)
                        .foregroundColor(BeUTheme.primaryText)
                        .multilineTextAlignment(.center)

                    Text("We'll use your profile, health context, and Apple Health to personalize your daily plan.")
                        .font(BeUTheme.bodyFont)
                        .foregroundColor(BeUTheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }

            Spacer()

            VStack(spacing: 12) {
                Button(action: onContinue) {
                    Text("Get started")
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
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 18)
        }
        .background(
            LinearGradient(
                colors: [BeUTheme.background, BeUTheme.accentSoft.opacity(0.5)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }
}

private struct BeUBodyProfileView: View {
    @Binding var baseline: Baseline
    let canGoBack: Bool
    let onBack: () -> Void
    let onContinue: () -> Void

    private var trimmedName: String {
        baseline.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isNameValid: Bool {
        trimmedName.count >= 2 && trimmedName.count <= 40
    }

    var body: some View {
        OnboardShell(
            stepIndex: 1,
            totalSteps: 4,
            canGoBack: canGoBack,
            onBack: onBack,
            buttonTitle: "Continue",
            buttonEnabled: isNameValid && baseline.age > 10 && baseline.heightCm > 80 && baseline.weightKg > 25,
            onContinue: {
                baseline.name = trimmedName
                onContinue()
            }
        ) {
            VStack(alignment: .leading, spacing: 22) {
                header(
                    kicker: "Step 1 of 4 · Baseline",
                    title: "About your body",
                    body: "These help BeU estimate your calorie, protein, water, and activity targets."
                )

                FieldGroup(title: "Name") {
                    VStack(alignment: .leading, spacing: 10) {
                        onboardingNameField

                        Text("We’ll use this to personalize your BeU experience.")
                            .font(BeUTheme.helperFont)
                            .foregroundColor(BeUTheme.secondaryText)
                    }
                }

                FieldGroup(title: "Gender") {
                    PillRow(values: Gender.allCases, title: \.title, selected: baseline.gender) { baseline.gender = $0 }
                }

                FieldGroup(title: "Age") {
                    StepInput(value: baseline.age, unit: "years", range: 13...100) {
                        baseline.age = $0
                    }
                }

                FieldGroup(title: "Height and weight") {
                    HStack(spacing: 12) {
                        StepInput(value: baseline.heightCm, unit: "cm", range: 100...230) {
                            baseline.heightCm = $0
                        }
                        StepInput(value: baseline.weightKg, unit: "kg", range: 30...250) {
                            baseline.weightKg = $0
                        }
                    }
                }

                HStack(alignment: .top, spacing: 12) {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(BeUTheme.accent.opacity(0.1))
                        .frame(width: 22, height: 22)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(BeUTheme.accent)
                        )

                    Text("Baseline profile. You can review this later. Changes should be rare — BeU uses it as your long-term baseline.")
                        .font(.system(size: 13.5))
                        .foregroundColor(BeUTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.black.opacity(0.03))
                )

                Text(BeUSafetyCopy.wellnessDisclaimer)
                    .font(BeUTheme.helperFont)
                    .foregroundColor(BeUTheme.secondaryText)
            }
        }
    }

    private var onboardingNameField: some View {
        BeUTextField(
            placeholder: "What should we call you?",
            text: $baseline.name,
            autocapitalization: .words,
            disableAutocorrection: true
        )
        .onChange(of: baseline.name) { _, newValue in
            if newValue.count > 40 {
                baseline.name = String(newValue.prefix(40))
            }
        }
    }
}

private struct BeUMedicalHistoryView: View {
    @Binding var baseline: Baseline
    let onBack: () -> Void
    let onContinue: () -> Void

    private let columns = [GridItem(.adaptive(minimum: 120), spacing: 8, alignment: .leading)]

    var body: some View {
        OnboardShell(
            stepIndex: 2,
            totalSteps: 4,
            canGoBack: true,
            onBack: onBack,
            buttonTitle: "Continue",
            buttonEnabled: true,
            onContinue: onContinue
        ) {
            VStack(alignment: .leading, spacing: 22) {
                header(
                    kicker: "Step 2 of 4 · Baseline",
                    title: "Health context",
                    body: "Select any that apply. We adjust the wording of your daily plan — never medical advice."
                )

                LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                    ForEach(conditionOptions, id: \.self) { condition in
                        Chip(
                            text: condition.title,
                            isSelected: baseline.medical.contains(condition)
                        ) {
                            toggle(condition)
                        }
                    }
                }

                FieldGroup(title: "Notes (optional)") {
                    textEditor(text: $baseline.medicalNotes, placeholder: "Anything else BeU should keep in mind?")
                }

                Text("This helps BeU personalize general wellness guidance. It is not used for diagnosis or treatment.")
                    .font(BeUTheme.helperFont)
                    .foregroundColor(BeUTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                Text(BeUSafetyCopy.wellnessDisclaimer)
                    .font(BeUTheme.helperFont)
                    .foregroundColor(BeUTheme.secondaryText)
            }
        }
    }

    private var conditionOptions: [Condition] {
        [
            .pcos, .diabetes, .thyroidCondition, .highBloodPressure, .highCholesterol,
            .anemiaLowIron, .pregnancy, .eatingDisorderHistory, .none, .preferNotToSay
        ]
    }

    private func toggle(_ condition: Condition) {
        if condition == .none || condition == .preferNotToSay {
            baseline.medical = [condition]
            return
        }

        baseline.medical.removeAll { $0 == .none || $0 == .preferNotToSay }
        if baseline.medical.contains(condition) {
            baseline.medical.removeAll { $0 == condition }
        } else {
            baseline.medical.append(condition)
        }
    }
}

private struct BeUBaselineSupplementsView: View {
    @Binding var baseline: Baseline
    let onBack: () -> Void
    let onContinue: () -> Void
    let onAdd: () -> Void
    let onEdit: (Supplement) -> Void

    var body: some View {
        OnboardShell(
            stepIndex: 3,
            totalSteps: 4,
            canGoBack: true,
            onBack: onBack,
            buttonTitle: baseline.supplements.isEmpty ? "Skip for now" : "Continue",
            buttonEnabled: true,
            onContinue: onContinue
        ) {
            VStack(alignment: .leading, spacing: 22) {
                header(
                    kicker: "Step 3 of 4 · Baseline",
                    title: "Supplements",
                    body: "Add what you regularly take. We'll just remind you in your daily plan."
                )

                if baseline.supplements.isEmpty {
                    VStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(BeUTheme.accent.opacity(0.08))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "pills.fill")
                                    .foregroundColor(BeUTheme.accent)
                            )
                        Text("Nothing yet")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(BeUTheme.primaryText)
                        Text("Add what you regularly take — we'll just remind you in your daily plan.")
                            .font(.system(size: 13.5))
                            .foregroundColor(BeUTheme.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                            .foregroundColor(Color.black.opacity(0.15))
                    )
                } else {
                    VStack(spacing: 10) {
                        ForEach(baseline.supplements) { supplement in
                            Button {
                                onEdit(supplement)
                            } label: {
                                HStack(spacing: 12) {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(BeUTheme.accent.opacity(0.1))
                                        .frame(width: 36, height: 36)
                                        .overlay(
                                            Image(systemName: "pills.fill")
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(BeUTheme.accent)
                                        )

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(supplement.name)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(BeUTheme.primaryText)

                                        Text(meta(for: supplement))
                                            .font(.system(size: 12.5))
                                            .foregroundColor(BeUTheme.secondaryText)
                                    }

                                    Spacer()

                                    Button {
                                        baseline.supplements.removeAll { $0.id == supplement.id }
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(BeUTheme.tertiaryText)
                                            .frame(width: 28, height: 28)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(BeUTheme.cardBackground)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .stroke(BeUTheme.hairline, lineWidth: 0.5)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Button(action: onAdd) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                        Text("Add supplement")
                    }
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundColor(BeUTheme.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                            .foregroundColor(Color.black.opacity(0.15))
                    )
                }
                .buttonStyle(.plain)

                Text("BeU does not recommend supplements, dosages, or interactions. Please consult a healthcare professional.")
                    .font(BeUTheme.helperFont)
                    .foregroundColor(BeUTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                Text(BeUSafetyCopy.wellnessDisclaimer)
                    .font(BeUTheme.helperFont)
                    .foregroundColor(BeUTheme.secondaryText)
            }
        }
    }

    private func meta(for supplement: Supplement) -> String {
        var parts: [String] = []
        if let time = supplement.timeOfDay?.title {
            parts.append(time)
        }
        parts.append(supplement.frequency.title)
        if let dosage = supplement.dosage, !dosage.isEmpty {
            parts.append(dosage)
        }
        return parts.joined(separator: " · ")
    }
}

private struct BeUBaselineSummaryView: View {
    let baseline: Baseline
    let onBack: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        OnboardShell(
            stepIndex: 4,
            totalSteps: 4,
            canGoBack: true,
            onBack: onBack,
            buttonTitle: "Confirm baseline",
            buttonEnabled: true,
            onContinue: onConfirm
        ) {
            VStack(alignment: .leading, spacing: 22) {
                header(
                    kicker: "Step 4 of 4 · Review",
                    title: "Your baseline",
                    body: "This becomes your long-term baseline. You can edit it later from your profile."
                )

                sectionCard(
                    kicker: "Body",
                    rows: [
                        ("Gender", baseline.gender.title),
                        ("Age", "\(baseline.age)"),
                        ("Height", "\(baseline.heightCm) cm"),
                        ("Weight", "\(baseline.weightKg) kg"),
                    ]
                )

                sectionCard(
                    kicker: "Health context",
                    rows: [
                        ("Conditions", baseline.medicalDisplay),
                    ],
                    extra: baseline.medicalNotes.isEmpty ? nil : ("Notes", baseline.medicalNotes)
                )

                VStack(alignment: .leading, spacing: 10) {
                    BeUKicker(text: "Supplements")
                    BeUCard {
                        if baseline.supplements.isEmpty {
                            Text("None added")
                                .font(BeUTheme.bodyFont)
                                .foregroundColor(BeUTheme.tertiaryText)
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            VStack(spacing: 14) {
                                ForEach(Array(baseline.supplements.enumerated()), id: \.element.id) { index, supplement in
                                    if index > 0 {
                                        Divider().overlay(BeUTheme.hairline)
                                    }
                                    HStack {
                                        Text(supplement.name)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(BeUTheme.primaryText)
                                        Spacer()
                                        Text(summary(for: supplement))
                                            .font(.system(size: 12.5))
                                            .foregroundColor(BeUTheme.secondaryText)
                                    }
                                }
                            }
                        }
                    }
                }

                Text(BeUSafetyCopy.wellnessDisclaimer)
                    .font(BeUTheme.helperFont)
                    .foregroundColor(BeUTheme.secondaryText)
            }
        }
    }

    private func sectionCard(kicker: String, rows: [(String, String)], extra: (String, String)? = nil) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            BeUKicker(text: kicker)
            BeUCard {
                VStack(spacing: 14) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                        if index > 0 {
                            Divider().overlay(BeUTheme.hairline)
                        }
                        rowView(title: row.0, value: row.1)
                    }
                    if let extra {
                        Divider().overlay(BeUTheme.hairline)
                        rowView(title: extra.0, value: extra.1)
                    }
                }
            }
        }
    }

    private func rowView(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 13.5))
                .foregroundColor(BeUTheme.secondaryText)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(BeUTheme.primaryText)
                .multilineTextAlignment(.trailing)
        }
    }

    private func summary(for supplement: Supplement) -> String {
        [supplement.timeOfDay?.title, supplement.frequency.title]
            .compactMap { $0 }
            .joined(separator: " · ")
    }
}

struct BeUGoalSetupView: View {
    enum Mode {
        case firstRun
        case changeGoal
    }

    let mode: Mode
    let baseline: Baseline
    let initialGoal: GoalConfig
    let onBack: () -> Void
    let onSave: (GoalConfig) -> Void

    @State private var goalConfig: GoalConfig

    init(
        mode: Mode,
        baseline: Baseline,
        initialGoal: GoalConfig,
        onBack: @escaping () -> Void,
        onSave: @escaping (GoalConfig) -> Void
    ) {
        self.mode = mode
        self.baseline = baseline
        self.initialGoal = initialGoal
        self.onBack = onBack
        self.onSave = onSave
        _goalConfig = State(initialValue: initialGoal)
    }

    var body: some View {
        OnboardShell(
            stepIndex: nil,
            totalSteps: 0,
            canGoBack: true,
            onBack: onBack,
            buttonTitle: mode == .firstRun ? "Save goal & continue" : "Save goal",
            buttonEnabled: true,
            onContinue: { onSave(goalConfig) }
        ) {
            VStack(alignment: .leading, spacing: 22) {
                header(
                    kicker: mode == .firstRun ? "Final step · Goal" : "Update goal",
                    title: mode == .firstRun ? "Set your goal" : "Change your goal",
                    body: "You can change this anytime. BeU will update your daily targets and plan."
                )

                VStack(spacing: 10) {
                    ForEach(Goal.allCases) { goal in
                        Button {
                            goalConfig.goal = goal
                            if goal == .maintain || goal == .wellness {
                                goalConfig.targetWeightKg = nil
                            } else {
                                goalConfig.targetWeightKg = goalConfig.targetWeightKg ?? (goal == .fatLoss ? max(baseline.weightKg - 6, 30) : baseline.weightKg + 4)
                                if goalConfig.customYears < 1 || goalConfig.customYears > 10 {
                                    goalConfig.customYears = 2
                                }
                            }
                        } label: {
                            HStack(spacing: 14) {
                                Circle()
                                    .stroke(goalConfig.goal == goal ? Color.white : BeUTheme.hairline, lineWidth: 1.5)
                                    .frame(width: 18, height: 18)
                                    .overlay(
                                        Circle()
                                            .fill(goalConfig.goal == goal ? Color.white : Color.clear)
                                            .frame(width: 8, height: 8)
                                    )

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(goal.title)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(goalConfig.goal == goal ? .white : BeUTheme.primaryText)
                                    Text(goal.description)
                                        .font(.system(size: 12))
                                        .foregroundColor(goalConfig.goal == goal ? Color.white.opacity(0.78) : BeUTheme.secondaryText)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(goalConfig.goal == goal ? BeUTheme.primaryText : BeUTheme.cardBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(BeUTheme.hairline, lineWidth: goalConfig.goal == goal ? 0 : 0.5)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                if goalConfig.goal == .fatLoss || goalConfig.goal == .muscle {
                    FieldGroup(title: "Target weight") {
                        StepInput(value: goalConfig.targetWeightKg ?? baseline.weightKg, unit: "kg", range: 30...250) {
                            goalConfig.targetWeightKg = $0
                        }
                    }

                    FieldGroup(title: "Timeline") {
                        timelinePicker
                    }
                }

                goalPreviewCard

                Text(BeUSafetyCopy.wellnessDisclaimer)
                    .font(BeUTheme.helperFont)
                    .foregroundColor(BeUTheme.secondaryText)
            }
        }
    }

    private var goalPreviewCard: some View {
        let targets = PlanService().calcTargets(
            goal: goalConfig.goal,
            weightKg: baseline.weightKg,
            heightCm: baseline.heightCm,
            age: baseline.age,
            gender: baseline.gender
        )
        return VStack(alignment: .leading, spacing: 10) {
            BeUKicker(text: "Based on your profile and goal")
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [BeUTheme.cardBackground, BeUTheme.accentSoft.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(BeUTheme.hairline, lineWidth: 0.5)
                )
                .frame(height: 148)
                .overlay {
                    HStack(spacing: 0) {
                        previewColumn(kicker: "Calories", value: "\(targets.kcal)", suffix: nil, subtitle: "kcal / day")
                        Rectangle()
                            .fill(BeUTheme.hairline)
                            .frame(width: 0.5)
                            .padding(.vertical, 22)
                        previewColumn(kicker: "Protein", value: "\(targets.protein)", suffix: "g", subtitle: "per day")
                    }
                    .padding(.horizontal, 20)
                }
        }
    }

    private var timelinePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8, alignment: .leading)], alignment: .leading, spacing: 8) {
                ForEach(TimelinePreset.allCases) { preset in
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            goalConfig.timeline = preset
                            if goalConfig.customYears < 1 || goalConfig.customYears > 10 {
                                goalConfig.customYears = 2
                            }
                        }
                    } label: {
                        Text(preset.label)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(goalConfig.timeline == preset ? .white : BeUTheme.primaryText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(goalConfig.timeline == preset ? BeUTheme.primaryText : BeUTheme.cardBackground)
                                    .overlay(
                                        Capsule(style: .continuous)
                                            .stroke(BeUTheme.hairline, lineWidth: goalConfig.timeline == preset ? 0 : 0.5)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            if goalConfig.timeline == .custom {
                customTimelinePanel
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var customTimelinePanel: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("CUSTOM TIMELINE")
                    .font(.system(size: 10.5, weight: .semibold))
                    .tracking(0.84)
                    .foregroundColor(BeUTheme.tertiaryText)

                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    TextField(
                        "",
                        text: Binding(
                            get: { "\(goalConfig.customYears)" },
                            set: { newValue in
                                let digits = newValue.filter(\.isNumber)
                                if let parsed = Int(digits) {
                                    goalConfig.customYears = min(max(parsed, 1), 10)
                                } else if digits.isEmpty {
                                    goalConfig.customYears = 1
                                }
                            }
                        )
                    )
                    .keyboardType(.numberPad)
                    .font(.system(size: 22, weight: .light))
                    .monospacedDigit()
                    .foregroundColor(BeUTheme.primaryText)
                    .frame(width: 64, alignment: .leading)

                    Text(goalConfig.customYears == 1 ? "year" : "years")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(BeUTheme.secondaryText)
                }
            }

            Spacer()

            VStack(spacing: 4) {
                timelineStepper(systemName: "chevron.up") {
                    goalConfig.customYears = min(goalConfig.customYears + 1, 10)
                }
                timelineStepper(systemName: "chevron.down") {
                    goalConfig.customYears = max(goalConfig.customYears - 1, 1)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(BeUTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(BeUTheme.hairline, lineWidth: 0.5)
                )
        )
    }

    private func timelineStepper(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(BeUTheme.primaryText)
                .frame(width: 32, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.black.opacity(0.04))
                )
        }
        .buttonStyle(.plain)
    }

    private func previewColumn(kicker: String, value: String, suffix: String?, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            BeUKicker(text: kicker)
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 32, weight: .light))
                    .monospacedDigit()
                    .foregroundColor(BeUTheme.primaryText)
                if let suffix {
                    Text(suffix)
                        .font(.system(size: 16))
                        .foregroundColor(BeUTheme.tertiaryText)
                }
            }
            Text(subtitle)
                .font(.system(size: 12.5))
                .foregroundColor(BeUTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct BeUSupplementEditorSheet: View {
    let existing: Supplement?
    let onSave: (Supplement) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var dosage: String
    @State private var timeOfDay: SupplementTime?
    @State private var frequency: SupplementFrequency

    init(existing: Supplement?, onSave: @escaping (Supplement) -> Void) {
        self.existing = existing
        self.onSave = onSave
        _name = State(initialValue: existing?.name ?? "")
        _dosage = State(initialValue: existing?.dosage ?? "")
        _timeOfDay = State(initialValue: existing?.timeOfDay)
        _frequency = State(initialValue: existing?.frequency ?? .daily)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    darkField(label: "Name", text: $name, placeholder: "Supplement name")
                    darkField(label: "Dosage", text: $dosage, placeholder: "Optional")

                    VStack(alignment: .leading, spacing: 10) {
                        BeUKicker(text: "When")
                        FlexibleChipWrap(items: SupplementTime.allCases, spacing: 8) { time in
                            Chip(
                                text: time.title,
                                isSelected: timeOfDay == time,
                                onTap: { timeOfDay = timeOfDay == time ? nil : time }
                            )
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        BeUKicker(text: "Frequency")
                        PillRow(values: SupplementFrequency.allCases, title: \.title, selected: frequency) {
                            frequency = $0
                        }
                    }

                    Button {
                        let now = Date()
                        let supplement = Supplement(
                            id: existing?.id ?? UUID().uuidString,
                            userId: existing?.userId ?? "local-user",
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            dosage: dosage.trimmedNil,
                            frequency: frequency,
                            timeOfDay: timeOfDay,
                            notes: existing?.notes,
                            isActive: existing?.isActive ?? true,
                            createdAt: existing?.createdAt ?? now,
                            updatedAt: now
                        )
                        onSave(supplement)
                        dismiss()
                    } label: {
                        Text("Save")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.white.opacity(0.16) : BeUTheme.primaryText)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Text("BeU does not provide medical or dosage advice. Please consult your healthcare professional before starting or stopping any supplement.")
                        .font(BeUTheme.helperFont)
                        .foregroundColor(BeUTheme.mutedText)
                }
                .padding(20)
            }
            .navigationTitle(existing == nil ? "Add supplement" : "Edit supplement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(BeUTheme.primaryText)
                }
            }
            .background(BeUTheme.background.ignoresSafeArea())
            .scrollContentBackground(.hidden)
        }
    }

    private func darkField(label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            BeUFormLabel(text: label)
            BeUTextField(placeholder: placeholder, text: text)
        }
    }
}

private struct FlexibleChipWrap<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let spacing: CGFloat
    @ViewBuilder let content: (Item) -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(chunked(items, size: 2).indices, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(chunked(items, size: 2)[row]) { item in
                        content(item)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func chunked(_ items: [Item], size: Int) -> [[Item]] {
        stride(from: 0, to: items.count, by: size).map { start in
            Array(items[start..<min(start + size, items.count)])
        }
    }
}

private extension Baseline {
    var medicalDisplay: String {
        let filtered = medical.filter { $0 != .none && $0 != .preferNotToSay }
        if medical.contains(.preferNotToSay) { return "Prefer not to say" }
        if filtered.isEmpty { return "None" }
        return filtered.map(\.title).joined(separator: ", ")
    }
}

private extension String {
    var trimmedNil: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private func header(kicker: String, title: String, body: String) -> some View {
    VStack(alignment: .leading, spacing: 10) {
        BeUKicker(text: kicker)
        Text(title)
            .font(BeUTheme.titleFont)
            .foregroundColor(BeUTheme.primaryText)
            .fixedSize(horizontal: false, vertical: true)
        Text(body)
            .font(BeUTheme.bodyFont)
            .foregroundColor(BeUTheme.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private func textEditor(text: Binding<String>, placeholder: String) -> some View {
    BeUTextArea(placeholder: placeholder, text: text, minHeight: 90)
}
