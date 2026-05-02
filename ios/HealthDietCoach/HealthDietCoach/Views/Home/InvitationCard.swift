import SwiftUI

struct InvitationCard: View {
    let model: DailyPlanCardModel
    let onOpenPlan: () -> Void

    var body: some View {
        BeUCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(BeUTheme.accent.opacity(0.13))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: "sparkles")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(BeUTheme.accent)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        KickerText(text: "For today")
                        Text("Today’s invitation")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(BeUTheme.primaryText)
                    }

                    Spacer()
                }

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(model.priorityActions.prefix(3).enumerated()), id: \.offset) { index, action in
                        HStack(alignment: .top, spacing: 12) {
                            Circle()
                                .stroke(BeUTheme.accent, lineWidth: 1.5)
                                .frame(width: 18, height: 18)
                                .overlay(
                                    Text("\(index + 1)")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(BeUTheme.accent)
                                )
                                .padding(.top, 1)

                            Text(action)
                                .font(BeUTheme.bodyFont)
                                .foregroundColor(BeUTheme.secondaryText)
                        }
                    }
                }

                if let note = model.healthContextNotes.first {
                    HStack(alignment: .top, spacing: 12) {
                        Rectangle()
                            .fill(BeUTheme.accent)
                            .frame(width: 2)

                        VStack(alignment: .leading, spacing: 6) {
                            KickerText(text: "For you")
                            Text(note)
                                .font(BeUTheme.helperFont)
                                .foregroundColor(BeUTheme.secondaryText)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(BeUTheme.accent.opacity(0.08))
                    )
                }

                if let reminder = model.supplementReminders.first {
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.black.opacity(0.03))
                            .frame(width: 26, height: 26)
                            .overlay(
                                Image(systemName: "pills.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(BeUTheme.accent)
                            )

                        Text(reminder)
                            .font(.system(size: 12.5))
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

                Button("View full plan", action: onOpenPlan)
                    .buttonStyle(BeUSecondaryButtonStyle())
            }
        }
    }
}

struct DailyActionPlanView: View {
    let model: DailyPlanCardModel
    @State private var isExplanationExpanded = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    BeUCard {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(alignment: .firstTextBaseline) {
                                Text("Today’s Plan")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundColor(BeUTheme.primaryText)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(model.readinessScore.map(String.init) ?? "--")
                                        .font(.system(size: 24, weight: .semibold))
                                        .monospacedDigit()
                                        .foregroundColor(BeUTheme.primaryText)
                                    Text(model.readinessStatus.uppercased())
                                        .font(BeUTheme.kickerFont)
                                        .tracking(1.4)
                                        .foregroundColor(BeUTheme.secondaryText)
                                }
                            }
                            Text("A practical wellness plan for today based on recovery, activity, and current guidance.")
                                .font(BeUTheme.helperFont)
                                .foregroundColor(BeUTheme.secondaryText)
                        }
                    }

                    BeUCard {
                        VStack(alignment: .leading, spacing: 10) {
                            KickerText(text: "Nutrition")
                            summaryRow("Calorie direction", model.calorieDirection)
                            summaryRow("Protein target", model.proteinTarget)
                            summaryRow("Carb adjustment", model.carbAdjustment)
                        }
                    }

                    BeUCard {
                        VStack(alignment: .leading, spacing: 10) {
                            KickerText(text: "Hydration")
                            Text("\(String(format: "%.1f", model.hydrationLiters))L")
                                .font(BeUTheme.bigNumber(size: 34))
                                .monospacedDigit()
                                .foregroundColor(BeUTheme.primaryText)
                        }
                    }

                    BeUCard {
                        VStack(alignment: .leading, spacing: 10) {
                            KickerText(text: "Meals")
                            ForEach(model.meals, id: \.self) { meal in
                                Text(meal)
                                    .font(BeUTheme.bodyFont)
                                    .foregroundColor(BeUTheme.secondaryText)
                            }
                        }
                    }

                    BeUCard {
                        VStack(alignment: .leading, spacing: 10) {
                            KickerText(text: "Priority actions")
                            ForEach(Array(model.priorityActions.enumerated()), id: \.offset) { index, action in
                                HStack(alignment: .top, spacing: 12) {
                                    Circle()
                                        .stroke(BeUTheme.accent, lineWidth: 1.5)
                                        .frame(width: 18, height: 18)
                                        .overlay(
                                            Text("\(index + 1)")
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundColor(BeUTheme.accent)
                                        )
                                        .padding(.top, 2)
                                    Text(action)
                                        .font(BeUTheme.bodyFont)
                                        .foregroundColor(BeUTheme.secondaryText)
                                }
                            }
                        }
                    }

                    if !model.supplementReminders.isEmpty {
                        BeUCard {
                            VStack(alignment: .leading, spacing: 10) {
                                KickerText(text: "Supplement reminders")
                                ForEach(model.supplementReminders, id: \.self) { reminder in
                                    Text(reminder)
                                        .font(BeUTheme.bodyFont)
                                        .foregroundColor(BeUTheme.secondaryText)
                                }
                            }
                        }
                    }

                    if !model.healthContextNotes.isEmpty {
                        BeUCard {
                            VStack(alignment: .leading, spacing: 10) {
                                KickerText(text: "Health context notes")
                                ForEach(model.healthContextNotes, id: \.self) { note in
                                    Text(note)
                                        .font(BeUTheme.bodyFont)
                                        .foregroundColor(BeUTheme.secondaryText)
                                }
                            }
                        }
                    }

                    BeUCard {
                        VStack(alignment: .leading, spacing: 10) {
                            KickerText(text: "Recovery note")
                            Text(model.recoveryNote)
                                .font(BeUTheme.bodyFont)
                                .foregroundColor(BeUTheme.secondaryText)
                        }
                    }

                    BeUCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isExplanationExpanded.toggle()
                                }
                            } label: {
                                HStack {
                                    Text("Why this plan?")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(BeUTheme.primaryText)
                                    Spacer()
                                    Image(systemName: isExplanationExpanded ? "chevron.up" : "chevron.down")
                                        .foregroundColor(BeUTheme.secondaryText)
                                }
                            }
                            .buttonStyle(.plain)

                            if isExplanationExpanded {
                                VStack(alignment: .leading, spacing: 10) {
                                    ForEach(model.explanation, id: \.self) { line in
                                        Text(line)
                                            .font(BeUTheme.bodyFont)
                                            .foregroundColor(BeUTheme.secondaryText)
                                    }
                                }
                            }
                        }
                    }

                    if let safetyNote = model.safetyNote {
                        BeUCard {
                            VStack(alignment: .leading, spacing: 10) {
                                KickerText(text: "Safety note")
                                Text(safetyNote)
                                    .font(BeUTheme.bodyFont)
                                    .foregroundColor(BeUTheme.secondaryText)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 120)
            }
            .background(BeUTheme.background.ignoresSafeArea())
            .navigationTitle("Today’s Plan")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func summaryRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(BeUTheme.bodyFont)
                .foregroundColor(BeUTheme.secondaryText)
            Spacer()
            Text(value)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(BeUTheme.primaryText)
        }
    }
}
