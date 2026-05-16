import Foundation

struct NextBestMealService {
    private struct LibraryMeal {
        let suggestion: NextBestMealSuggestion
        let tags: Set<String>
        let supports: Set<String>
        let avoids: Set<String>
        let mealType: MealType
    }

    private let library: [LibraryMeal] = [
        .init(
            suggestion: .init(
                id: "soya-roti",
                name: "Soya chunks curry with roti",
                mealType: MealType.dinner.rawValue,
                portion: "1 bowl soya curry + 1 roti",
                estimatedCalories: 500,
                estimatedProteinGrams: 38,
                reason: "High protein and balanced for a full meal.",
                tags: ["high_protein", "balanced", "dinner"]
            ),
            tags: ["high_protein", "balanced", "carb_pairing", "fiber"],
            supports: ["fat_loss", "muscle", "maintain", "wellness", "pcos"],
            avoids: [],
            mealType: .dinner
        ),
        .init(
            suggestion: .init(
                id: "tofu-salad",
                name: "Tofu bhurji with salad",
                mealType: MealType.lunch.rawValue,
                portion: "150g tofu + 1 bowl salad",
                estimatedCalories: 360,
                estimatedProteinGrams: 32,
                reason: "Lean protein with a lighter calorie load.",
                tags: ["high_protein", "light", "fiber"]
            ),
            tags: ["high_protein", "lean", "fiber", "light", "vegan", "pcos"],
            supports: ["fat_loss", "maintain", "wellness", "pcos", "vegan"],
            avoids: [],
            mealType: .lunch
        ),
        .init(
            suggestion: .init(
                id: "paneer-roti",
                name: "Paneer bhurji with roti",
                mealType: MealType.dinner.rawValue,
                portion: "1 bowl paneer bhurji + 1 roti",
                estimatedCalories: 550,
                estimatedProteinGrams: 35,
                reason: "Protein-led and satisfying for dinner.",
                tags: ["high_protein", "balanced", "dinner"]
            ),
            tags: ["high_protein", "balanced", "carb_pairing", "vegetarian"],
            supports: ["muscle", "maintain", "wellness", "fat_loss", "pcos"],
            avoids: ["vegan"],
            mealType: .dinner
        ),
        .init(
            suggestion: .init(
                id: "dal-tofu-salad",
                name: "Dal soup + tofu salad",
                mealType: MealType.dinner.rawValue,
                portion: "1 bowl dal soup + 100g tofu salad",
                estimatedCalories: 420,
                estimatedProteinGrams: 30,
                reason: "Balanced and easy if recovery feels lower.",
                tags: ["balanced", "fiber", "high_protein"]
            ),
            tags: ["high_protein", "fiber", "light", "pcos", "vegan"],
            supports: ["fat_loss", "maintain", "wellness", "pcos", "vegan"],
            avoids: [],
            mealType: .dinner
        ),
        .init(
            suggestion: .init(
                id: "hung-curd-fruit",
                name: "Hung curd bowl with fruit",
                mealType: MealType.breakfast.rawValue,
                portion: "250g hung curd + fruit",
                estimatedCalories: 300,
                estimatedProteinGrams: 25,
                reason: "A lighter protein-focused meal when calories are tighter.",
                tags: ["protein", "light", "breakfast"]
            ),
            tags: ["high_protein", "light", "fiber", "quick", "vegetarian"],
            supports: ["fat_loss", "maintain", "wellness", "pcos"],
            avoids: ["vegan"],
            mealType: .breakfast
        ),
        .init(
            suggestion: .init(
                id: "moong-curd",
                name: "Moong dal chilla with curd",
                mealType: MealType.breakfast.rawValue,
                portion: "2 chillas + 1 bowl curd",
                estimatedCalories: 350,
                estimatedProteinGrams: 22,
                reason: "A balanced breakfast with steady protein.",
                tags: ["balanced", "breakfast", "fiber"]
            ),
            tags: ["balanced", "fiber", "vegetarian", "pcos"],
            supports: ["fat_loss", "maintain", "wellness", "pcos"],
            avoids: ["vegan"],
            mealType: .breakfast
        ),
        .init(
            suggestion: .init(
                id: "sprouts-chaat",
                name: "Sprouts chaat",
                mealType: MealType.snack.rawValue,
                portion: "1 large bowl",
                estimatedCalories: 250,
                estimatedProteinGrams: 18,
                reason: "Fiber-rich and useful when the next meal should stay light.",
                tags: ["snack", "fiber", "light"]
            ),
            tags: ["fiber", "light", "protein_snack", "vegan", "pcos"],
            supports: ["fat_loss", "maintain", "wellness", "pcos", "vegan"],
            avoids: [],
            mealType: .snack
        ),
        .init(
            suggestion: .init(
                id: "roasted-chana",
                name: "Roasted chana",
                mealType: MealType.snack.rawValue,
                portion: "1 small bowl",
                estimatedCalories: 180,
                estimatedProteinGrams: 10,
                reason: "Very light and useful when calories are nearly used up.",
                tags: ["snack", "light"]
            ),
            tags: ["light", "vegan", "fiber"],
            supports: ["fat_loss", "maintain", "wellness", "pcos", "vegan"],
            avoids: [],
            mealType: .snack
        ),
        .init(
            suggestion: .init(
                id: "rajma-curd",
                name: "Rajma bowl with curd",
                mealType: MealType.lunch.rawValue,
                portion: "1 bowl rajma + 1 small curd",
                estimatedCalories: 600,
                estimatedProteinGrams: 25,
                reason: "Protein plus carbs works well when calories and activity are higher.",
                tags: ["balanced", "carb_pairing", "lunch"]
            ),
            tags: ["fiber", "carb_pairing", "vegetarian"],
            supports: ["muscle", "maintain", "wellness"],
            avoids: ["vegan"],
            mealType: .lunch
        ),
        .init(
            suggestion: .init(
                id: "khichdi-curd",
                name: "Khichdi with curd",
                mealType: MealType.lunch.rawValue,
                portion: "1 bowl khichdi + 1 small curd",
                estimatedCalories: 480,
                estimatedProteinGrams: 22,
                reason: "Easy, balanced, and gentler when recovery feels mixed.",
                tags: ["balanced", "easy", "lunch"]
            ),
            tags: ["balanced", "easy", "fiber", "vegetarian", "pcos"],
            supports: ["maintain", "wellness", "pcos", "fat_loss"],
            avoids: ["vegan"],
            mealType: .lunch
        ),
    ]

    func generateNextBestMeal(context: NextBestMealContext) -> NextBestMealResult {
        let caloriesRemaining = max(context.calorieTarget - context.caloriesConsumed, 0)
        let proteinRemaining = max(context.proteinTargetGrams - context.proteinConsumedGrams, 0)
        let targetMealType = resolvedNextMealType(currentHour: context.currentHour, loggedMeals: context.mealsLoggedToday)

        let candidates = library
            .filter { $0.mealType == targetMealType }
            .filter { includeMeal($0, for: context) }
            .map { meal in
                (meal.suggestion, score: mealScore(meal, context: context, caloriesRemaining: caloriesRemaining, proteinRemaining: proteinRemaining))
            }
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.0.estimatedProteinGrams > rhs.0.estimatedProteinGrams
                }
                return lhs.score > rhs.score
            }

        guard let primary = candidates.first?.0 else {
            return .init(primary: nil, alternates: [])
        }

        let primaryWithReason = primaryWithRefinedReason(primary, context: context, caloriesRemaining: caloriesRemaining, proteinRemaining: proteinRemaining)
        let alternates = candidates
            .dropFirst()
            .prefix(3)
            .map { primaryWithRefinedReason($0.0, context: context, caloriesRemaining: caloriesRemaining, proteinRemaining: proteinRemaining) }

        return .init(primary: primaryWithReason, alternates: Array(alternates))
    }

    private func resolvedNextMealType(currentHour: Int, loggedMeals: [MealLog]) -> MealType {
        let loggedTypes = Set(loggedMeals.map(\.mealType))
        let sequence: [MealType]

        switch currentHour {
        case ..<11:
            sequence = [.breakfast, .lunch, .snack, .dinner]
        case ..<16:
            sequence = [.lunch, .snack, .dinner, .breakfast]
        case ..<19:
            sequence = [.snack, .dinner, .lunch, .breakfast]
        default:
            sequence = [.dinner, .snack, .lunch, .breakfast]
        }

        if let nextUnlogged = sequence.first(where: { loggedTypes.contains($0) == false }) {
            return nextUnlogged
        }

        return .snack
    }

    private func includeMeal(_ meal: LibraryMeal, for context: NextBestMealContext) -> Bool {
        let goalKey = context.goalType.lowercased()
        let diet = context.dietPreference?.lowercased() ?? "indian_vegetarian"
        let conditions = Set(context.healthConditions.map { $0.lowercased() })

        if diet == "vegan", meal.avoids.contains("vegan") {
            return false
        }

        if meal.supports.contains(goalKey) == false &&
            meal.supports.intersection(["fat_loss", "muscle", "maintain", "wellness"]).isEmpty == false {
            return false
        }

        if conditions.contains("pcos") == false, meal.supports.contains("pcos") {
            return true
        }

        return true
    }

    private func mealScore(
        _ meal: LibraryMeal,
        context: NextBestMealContext,
        caloriesRemaining: Int,
        proteinRemaining: Double
    ) -> Int {
        var score = 0
        let goal = context.goalType.lowercased()
        let readiness = (context.readinessStatus ?? "").lowercased()
        let conditions = Set(context.healthConditions.map { $0.lowercased() })

        if proteinRemaining >= 40 {
            score += Int(meal.suggestion.estimatedProteinGrams * 1.4)
        } else if proteinRemaining >= 25 {
            score += Int(meal.suggestion.estimatedProteinGrams * 1.1)
        } else {
            score += Int(meal.suggestion.estimatedProteinGrams)
        }

        if caloriesRemaining <= 200 {
            score += meal.suggestion.estimatedCalories <= 220 ? 35 : -30
        } else if caloriesRemaining <= 400, proteinRemaining >= 25 {
            score += meal.tags.contains("lean") || meal.tags.contains("light") ? 24 : -10
            score += meal.suggestion.estimatedCalories <= 420 ? 14 : -14
        } else if caloriesRemaining > 700, proteinRemaining >= 25 {
            score += meal.tags.contains("carb_pairing") ? 18 : 4
            score += meal.suggestion.estimatedCalories >= 420 ? 8 : 0
        } else {
            let budgetGap = abs(meal.suggestion.estimatedCalories - caloriesRemaining / max(context.mealsLoggedToday.count == 0 ? 3 : 2, 1))
            score += max(0, 22 - budgetGap / 15)
        }

        switch goal {
        case "fat_loss":
            score += meal.tags.contains("high_protein") ? 18 : 0
            score += meal.tags.contains("fiber") ? 10 : 0
            score -= meal.suggestion.estimatedCalories > 580 ? 18 : 0
        case "muscle":
            score += meal.tags.contains("carb_pairing") ? 16 : 0
            score += meal.suggestion.estimatedCalories >= 400 ? 10 : 0
        default:
            score += meal.tags.contains("balanced") ? 14 : 0
        }

        if readiness == "low" {
            score += meal.tags.contains("easy") || meal.tags.contains("light") || meal.tags.contains("balanced") ? 16 : -10
        } else if readiness == "good" || readiness == "high" {
            score += meal.tags.contains("high_protein") ? 8 : 0
        }

        if conditions.contains("pcos") {
            score += meal.tags.contains("fiber") ? 10 : 0
            score += meal.tags.contains("balanced") ? 8 : 0
        }

        return score
    }

    private func primaryWithRefinedReason(
        _ suggestion: NextBestMealSuggestion,
        context: NextBestMealContext,
        caloriesRemaining: Int,
        proteinRemaining: Double
    ) -> NextBestMealSuggestion {
        var reasons: [String] = []
        if proteinRemaining >= 40 {
            reasons.append("Protein is still a priority.")
        } else if caloriesRemaining <= 400 && proteinRemaining >= 25 {
            reasons.append("Calories are tighter, so this keeps protein efficient.")
        } else if context.goalType.lowercased() == "muscle" {
            reasons.append("This supports protein and steady refuelling.")
        } else if (context.readinessStatus ?? "").lowercased() == "low" {
            reasons.append("This keeps the meal balanced and easy.")
        } else {
            reasons.append("This fits today’s targets well.")
        }

        if context.healthConditions.map({ $0.lowercased() }).contains("pcos") {
            reasons.append("Balanced and fiber-aware for today’s context.")
        }

        return .init(
            id: suggestion.id,
            name: suggestion.name,
            mealType: suggestion.mealType,
            portion: suggestion.portion,
            estimatedCalories: suggestion.estimatedCalories,
            estimatedProteinGrams: suggestion.estimatedProteinGrams,
            reason: reasons.prefix(2).joined(separator: " "),
            tags: suggestion.tags
        )
    }
}

struct WeeklyReviewService {
    func generateWeeklyReview(context: WeeklyReviewContext) -> WeeklyReview? {
        let snapshots = context.dailySnapshots.sorted { $0.date < $1.date }
        let loggedDays = snapshots.filter { $0.mealsLogged > 0 }
        guard snapshots.isEmpty == false else { return nil }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        let isoFormatter = ISODateOnlyFormatter.shared
        let startDate = isoFormatter.date(from: snapshots.first!.date)
        let endDate = isoFormatter.date(from: snapshots.last!.date)
        let weekRangeText = [startDate, endDate]
            .compactMap { $0.map { dateFormatter.string(from: $0) } }
            .joined(separator: " – ")

        guard loggedDays.count >= 3 else {
            return WeeklyReview(
                headline: "Log a few more days to unlock your weekly review.",
                weekRangeText: weekRangeText,
                stepHitDays: 0,
                proteinHitDays: 0,
                calorieHitDays: 0,
                scorecards: [
                    .init(id: "activity", title: "Activity", status: "Moderate", metric: "Need more days", insight: "A few more logged days will make this useful."),
                    .init(id: "nutrition", title: "Nutrition", status: "Moderate", metric: "Need more days", insight: "Protein and calorie patterns will appear after a few more logs."),
                    .init(id: "recovery", title: "Recovery", status: "Moderate", metric: "Limited data", insight: "Recovery needs more logged days to show a trend."),
                    .init(id: "consistency", title: "Consistency", status: "Moderate", metric: "\(loggedDays.count)/7 days", insight: "Build the daily logging habit first."),
                ],
                recommendationHeadline: "Keep logging this week to unlock tailored guidance.",
                recommendationChips: ["Meal consistency"],
                wins: [],
                focus: ["Log meals most days this week."],
                adjustments: [
                    .init(id: "consistency", title: "Build the habit", description: "Log a few more days before changing anything.")
                ],
                hasEnoughData: false
            )
        }

        let stepsHitDays = snapshots.filter { $0.steps >= context.stepTarget }.count
        let proteinHitDays = snapshots.filter { $0.proteinConsumed >= Double(context.proteinTarget) }.count
        let calorieHitDays = snapshots.filter { calorieHit(for: $0.caloriesConsumed, target: context.calorieTarget, goal: context.goalType) }.count
        let readinessSamples = snapshots.compactMap(\.readinessScore)
        let mealLoggingDays = snapshots.filter { $0.mealsLogged > 0 }.count

        let activityStatus = status(for: stepsHitDays)
        let nutritionStatus = status(for: proteinHitDays)
        let recoveryStatus = readinessSamples.count >= 3 ? status(for: readinessSamples.filter { $0 >= 60 }.count) : "Moderate"
        let consistencyStatus = status(for: mealLoggingDays)

        let scorecards = [
            WeeklyScorecard(
                id: "activity",
                title: "Activity",
                status: activityStatus,
                metric: "\(stepsHitDays)/7 step days",
                insight: stepsHitDays >= 4 ? "Movement stayed fairly steady." : "Movement needs a steadier baseline."
            ),
            WeeklyScorecard(
                id: "nutrition",
                title: "Nutrition",
                status: nutritionStatus,
                metric: "\(proteinHitDays)/7 protein days",
                insight: proteinHitDays >= 4 ? "Protein was reasonably consistent." : "Protein needs earlier attention."
            ),
            WeeklyScorecard(
                id: "recovery",
                title: "Recovery",
                status: recoveryStatus,
                metric: readinessMetric(readinessSamples),
                insight: readinessSamples.count >= 3 ? "Recovery stayed mostly stable." : "Recovery data is limited."
            ),
            WeeklyScorecard(
                id: "consistency",
                title: "Consistency",
                status: consistencyStatus,
                metric: "\(mealLoggingDays)/7 logging days",
                insight: mealLoggingDays >= 4 ? "The logging habit is building." : "Consistency comes before optimization."
            ),
        ]

        let headline = weeklyHeadline(
            activityStatus: activityStatus,
            nutritionStatus: nutritionStatus,
            recoveryStatus: recoveryStatus,
            consistencyStatus: consistencyStatus
        )
        let chips = recommendationChips(
            goalType: context.goalType,
            stepsHitDays: stepsHitDays,
            proteinHitDays: proteinHitDays,
            calorieHitDays: calorieHitDays,
            recoveryStatus: recoveryStatus,
            mealLoggingDays: mealLoggingDays
        )
        let wins = weeklyWins(
            stepsHitDays: stepsHitDays,
            proteinHitDays: proteinHitDays,
            calorieHitDays: calorieHitDays,
            mealLoggingDays: mealLoggingDays
        )
        let focus = weeklyFocus(
            stepsHitDays: stepsHitDays,
            proteinHitDays: proteinHitDays,
            calorieHitDays: calorieHitDays,
            recoveryStatus: recoveryStatus,
            mealLoggingDays: mealLoggingDays
        )
        let adjustments = chips.prefix(3).enumerated().map { index, chip in
            WeeklyAdjustment(id: "adjustment-\(index)", title: chip, description: adjustmentCopy(for: chip))
        }

        return WeeklyReview(
            headline: headline,
            weekRangeText: weekRangeText,
            stepHitDays: stepsHitDays,
            proteinHitDays: proteinHitDays,
            calorieHitDays: calorieHitDays,
            scorecards: scorecards,
            recommendationHeadline: chips.first.map { "Next week, keep the focus on \($0.lowercased())." } ?? "Keep the same steady approach next week.",
            recommendationChips: Array(chips.prefix(3)),
            wins: Array(wins.prefix(3)),
            focus: Array(focus.prefix(3)),
            adjustments: Array(adjustments.prefix(3)),
            hasEnoughData: true
        )
    }

    private func calorieHit(for calories: Int, target: Int, goal: String) -> Bool {
        switch goal.lowercased() {
        case "fat_loss":
            return calories <= target + 100 && calories >= target - 300
        case "muscle":
            return calories >= target - 100
        default:
            return abs(calories - target) <= 200
        }
    }

    private func status(for hitDays: Int) -> String {
        switch hitDays {
        case 6...7: return "Strong"
        case 4...5: return "Good"
        case 2...3: return "Moderate"
        default: return "Needs focus"
        }
    }

    private func readinessMetric(_ values: [Int]) -> String {
        guard !values.isEmpty else { return "Limited data" }
        let average = Int((Double(values.reduce(0, +)) / Double(values.count)).rounded())
        return "Avg \(average)"
    }

    private func weeklyHeadline(activityStatus: String, nutritionStatus: String, recoveryStatus: String, consistencyStatus: String) -> String {
        if recoveryStatus == "Needs focus" {
            return "Recovery needs more focus next week"
        }
        if activityStatus == "Strong", nutritionStatus == "Needs focus" || nutritionStatus == "Moderate" {
            return "You stayed active, but protein needs attention"
        }
        if consistencyStatus == "Needs focus" {
            return "Build the habit before optimizing targets"
        }
        if [activityStatus, nutritionStatus, recoveryStatus, consistencyStatus].allSatisfy({ $0 == "Strong" || $0 == "Good" }) {
            return "This week was consistent"
        }
        return "This week had momentum, with room to tighten the basics"
    }

    private func recommendationChips(
        goalType: String,
        stepsHitDays: Int,
        proteinHitDays: Int,
        calorieHitDays: Int,
        recoveryStatus: String,
        mealLoggingDays: Int
    ) -> [String] {
        var chips: [String] = []
        if proteinHitDays <= 3 { chips.append("Protein") }
        if recoveryStatus == "Needs focus" || recoveryStatus == "Moderate" { chips.append("Recovery") }
        if stepsHitDays <= 3 && goalType.lowercased() != "muscle" { chips.append("Activity") }
        if mealLoggingDays <= 3 { chips.append("Meal consistency") }
        if calorieHitDays <= 3 { chips.append(goalType.lowercased() == "fat_loss" ? "Lighter dinners" : "Keep calories stable") }
        if goalType.lowercased() == "muscle" { chips.append("Strength routine") }
        if chips.isEmpty { chips.append("Stay consistent") }
        return Array(NSOrderedSet(array: chips)) as? [String] ?? chips
    }

    private func weeklyWins(stepsHitDays: Int, proteinHitDays: Int, calorieHitDays: Int, mealLoggingDays: Int) -> [String] {
        var wins: [String] = []
        if stepsHitDays >= 4 { wins.append("Movement stayed fairly consistent.") }
        if proteinHitDays >= 4 { wins.append("Protein hit more often than not.") }
        if calorieHitDays >= 4 { wins.append("Calories stayed close to target on several days.") }
        if mealLoggingDays >= 4 { wins.append("You kept the meal logging habit alive.") }
        return wins.isEmpty ? ["You kept showing up this week."] : wins
    }

    private func weeklyFocus(stepsHitDays: Int, proteinHitDays: Int, calorieHitDays: Int, recoveryStatus: String, mealLoggingDays: Int) -> [String] {
        var focus: [String] = []
        if proteinHitDays <= 3 { focus.append("Prioritize protein earlier in the day.") }
        if stepsHitDays <= 3 { focus.append("Add one reliable walking block most days.") }
        if calorieHitDays <= 3 { focus.append("Keep meals steadier on lower-activity days.") }
        if recoveryStatus == "Needs focus" || recoveryStatus == "Moderate" { focus.append("Give sleep and recovery more structure.") }
        if mealLoggingDays <= 3 { focus.append("Log meals more consistently before chasing finer changes.") }
        return focus.isEmpty ? ["Keep repeating the same stable routine next week."] : focus
    }

    private func adjustmentCopy(for chip: String) -> String {
        switch chip {
        case "Protein":
            return "Prioritize protein earlier and make the first main meal stronger."
        case "Recovery":
            return "Keep training balanced and protect sleep timing."
        case "Activity":
            return "Use one practical walk block to keep movement steady."
        case "Hydration":
            return "Front-load water earlier in the day."
        case "Meal consistency":
            return "Aim to log meals most days before making bigger changes."
        case "Lighter dinners":
            return "Use simpler dinners when activity is lower."
        case "Strength routine":
            return "Keep one or two dependable strength sessions in the week."
        case "Keep calories stable":
            return "Avoid swinging too far above or below target."
        default:
            return "Keep the next week steady and repeatable."
        }
    }
}

struct MealQualityService {
    func scoreMeal(items: [DetectedFoodItem], context: MealQualityContext) -> MealQualityResult? {
        guard items.isEmpty == false else { return nil }
        let totalCalories = items.reduce(0) { $0 + $1.calories }
        let totalProtein = items.reduce(0) { $0 + $1.proteinGrams }
        let mealType = context.mealType ?? inferredMealType(from: items)

        let proteinStatus = proteinIndicator(totalProtein: totalProtein, mealType: mealType)
        let fiberStatus = fiberIndicator(items: items)
        let calorieStatus = calorieFitIndicator(
            calories: totalCalories,
            mealType: mealType,
            calorieTarget: context.calorieTarget,
            remainingCalories: context.caloriesRemaining
        )
        let goalStatus = goalFitIndicator(
            items: items,
            totalCalories: totalCalories,
            totalProtein: totalProtein,
            mealType: mealType,
            goalType: context.goalType
        )

        let indicators = [
            MealQualityIndicator(id: "protein", label: "Protein", status: proteinStatus),
            MealQualityIndicator(id: "fiber", label: "Fiber / Veg", status: fiberStatus),
            MealQualityIndicator(id: "calorie", label: "Calorie fit", status: calorieStatus),
            MealQualityIndicator(id: "goal", label: "Goal fit", status: goalStatus),
        ]

        let average = indicators
            .map { numericValue(for: $0.status) }
            .reduce(0, +) / Double(indicators.count)

        let rating: String
        let meter: Int
        switch average {
        case 3.5...:
            rating = "Excellent"
            meter = 4
        case 2.75...:
            rating = "Good"
            meter = 3
        case 2.0...:
            rating = "Fair"
            meter = 2
        default:
            rating = "Needs improvement"
            meter = 1
        }

        let summary = mealSummary(
            rating: rating,
            proteinStatus: proteinStatus,
            fiberStatus: fiberStatus,
            calorieStatus: calorieStatus
        )
        let tip = mealTip(
            proteinStatus: proteinStatus,
            fiberStatus: fiberStatus,
            calorieStatus: calorieStatus,
            goalStatus: goalStatus
        )

        return MealQualityResult(
            rating: rating,
            meter: meter,
            indicators: indicators,
            summary: summary,
            tip: tip
        )
    }

    private func proteinIndicator(totalProtein: Double, mealType: MealType?) -> String {
        let snack = mealType == .snack
        switch totalProtein {
        case let protein where snack && protein >= 15: return "Strong"
        case let protein where snack && protein >= 8: return "Good"
        case let protein where snack && protein >= 4: return "Moderate"
        case let protein where !snack && protein >= 30: return "Strong"
        case let protein where !snack && protein >= 20: return "Good"
        case let protein where !snack && protein >= 10: return "Moderate"
        default: return "Needs improvement"
        }
    }

    private func fiberIndicator(items: [DetectedFoodItem]) -> String {
        let lowerNames = items.map { $0.name.lowercased() }
        let strongMatches = lowerNames.filter { name in
            ["salad", "vegetable", "sprout", "fruit", "dal", "lentil", "beans", "chickpea", "rajma", "chole"].contains(where: name.contains)
        }

        let hasBeanOnly = lowerNames.contains { name in
            ["dal", "lentil", "beans", "chickpea", "rajma", "chole"].contains(where: name.contains)
        }

        if strongMatches.count >= 2 { return "Strong" }
        if strongMatches.count == 1 { return "Good" }
        if hasBeanOnly { return "Moderate" }
        return "Needs improvement"
    }

    private func calorieFitIndicator(calories: Int, mealType: MealType?, calorieTarget: Int, remainingCalories: Int?) -> String {
        if let remainingCalories {
            if calories <= remainingCalories { return remainingCalories - calories <= 150 ? "Strong" : "Good" }
            if calories <= remainingCalories + 120 { return "Moderate" }
            return "Needs improvement"
        }

        let ratio: Double
        switch mealType {
        case .breakfast:
            ratio = 0.25
        case .snack:
            ratio = 0.1
        default:
            ratio = 0.35
        }

        let ideal = Double(calorieTarget) * ratio
        let gap = abs(Double(calories) - ideal)
        if gap <= 80 { return "Strong" }
        if gap <= 160 { return "Good" }
        if gap <= 260 { return "Moderate" }
        return "Needs improvement"
    }

    private func goalFitIndicator(items: [DetectedFoodItem], totalCalories: Int, totalProtein: Double, mealType: MealType?, goalType: String) -> String {
        let hasFiber = fiberIndicator(items: items) != "Needs improvement"
        switch goalType.lowercased() {
        case "fat_loss":
            if totalProtein >= 25 && totalCalories <= 550 && hasFiber { return "Strong" }
            if totalProtein >= 18 && totalCalories <= 650 { return "Good" }
            if totalProtein >= 10 { return "Moderate" }
            return "Needs improvement"
        case "muscle":
            if totalProtein >= 25 && totalCalories >= 350 { return "Strong" }
            if totalProtein >= 18 { return "Good" }
            if totalCalories >= 250 { return "Moderate" }
            return "Needs improvement"
        default:
            if hasFiber && totalProtein >= 18 { return "Strong" }
            if totalProtein >= 12 { return "Good" }
            if totalCalories > 0 { return "Moderate" }
            return "Needs improvement"
        }
    }

    private func inferredMealType(from items: [DetectedFoodItem]) -> MealType? {
        let names = items.map { $0.name.lowercased() }.joined(separator: " ")
        if names.contains("chana") || names.contains("sprout") { return .snack }
        return nil
    }

    private func numericValue(for status: String) -> Double {
        switch status {
        case "Strong": return 4
        case "Good": return 3
        case "Moderate": return 2
        default: return 1
        }
    }

    private func mealSummary(rating: String, proteinStatus: String, fiberStatus: String, calorieStatus: String) -> String {
        if rating == "Excellent" {
            return "This meal fits your target and supports protein well."
        }
        if proteinStatus == "Good" || proteinStatus == "Strong", fiberStatus == "Needs improvement" {
            return "Good protein, but adding vegetables would make it more balanced."
        }
        if calorieStatus == "Needs improvement" {
            return "This meal is heavy for the calories you have left today."
        }
        return "This meal is workable, with one or two easy improvements."
    }

    private func mealTip(proteinStatus: String, fiberStatus: String, calorieStatus: String, goalStatus: String) -> String {
        if proteinStatus == "Needs improvement" || proteinStatus == "Moderate" {
            return "Add curd, tofu, paneer, or sprouts to improve protein."
        }
        if fiberStatus == "Needs improvement" {
            return "Add salad, vegetables, fruit, or dal for more fiber."
        }
        if calorieStatus == "Needs improvement" {
            return "Keep the portion lighter if your calories are tight."
        }
        if goalStatus == "Moderate" || goalStatus == "Needs improvement" {
            return "Keep the next meal aligned with the rest of today’s target."
        }
        return "This meal already fits well. Keep the same balance next time."
    }
}

struct DailyDeltaService {
    func getDailyDelta(context: DailyDeltaContext) -> DailyDelta? {
        guard context.yesterday != nil || context.averageSteps != nil || context.averageActiveEnergy != nil else {
            return nil
        }

        var activity: [String] = []
        var nutrition: [String] = []
        var recovery: [String] = []

        let today = context.today
        let averageSteps = context.averageSteps ?? context.stepTarget
        if today.steps >= Int(Double(context.stepTarget) * 0.8) {
            activity.append("You’re ahead on movement for this time of day.")
        } else if today.steps < max(averageSteps - 1500, 0) {
            activity.append("You’re behind on steps compared with your usual day.")
        }

        if let activeEnergy = today.activeEnergyBurned, let averageActiveEnergy = context.averageActiveEnergy, activeEnergy > averageActiveEnergy + 120 {
            activity.append("You burned more calories than usual today.")
        }

        let proteinRemaining = max(context.proteinTarget - Int(today.proteinConsumed.rounded()), 0)
        if proteinRemaining >= 25 {
            nutrition.append("Protein is still behind your target.")
        }

        let caloriesRemaining = context.calorieTarget - today.caloriesConsumed
        if caloriesRemaining <= 250 {
            nutrition.append("Calories are tight for the rest of the day.")
        }

        if proteinRemaining >= 20 {
            nutrition.append("Your next meal should be protein-led.")
        }

        switch (today.readinessStatus ?? "").lowercased() {
        case "low":
            recovery.append("Readiness is lower today, so training stays lighter.")
        case "good", "high":
            recovery.append("Readiness looks good, so your normal plan is fine.")
        case "limited_data":
            recovery.append("Recovery data is limited, so BeU is using your goal and progress.")
        default:
            break
        }

        if recovery.isEmpty, let yesterday = context.yesterday, let todayScore = today.readinessScore, let yesterdayScore = yesterday.readinessScore, todayScore <= yesterdayScore - 8 {
            recovery.append("Recovery is a bit lower than yesterday, so today stays more balanced.")
        }

        let bullets = Array((activity + nutrition + recovery).prefix(4))
        guard bullets.isEmpty == false else { return nil }

        let tldr: String
        if nutrition.contains("Calories are tight for the rest of the day.") {
            tldr = "Today’s plan focuses on protein because calories are tight."
        } else if activity.contains("You’re ahead on movement for this time of day.") {
            tldr = "Your plan is lighter because activity is ahead and protein is still the focus."
        } else if recovery.contains("Readiness is lower today, so training stays lighter.") {
            tldr = "Recovery is lower today, so the plan is intentionally lighter."
        } else {
            tldr = "No major changes today. Stay consistent."
        }

        let homePreview = nutrition.first ?? activity.first ?? recovery.first ?? "No major changes today."

        let groups = [
            DailyDeltaGroup(id: "activity", title: "Activity", bullets: Array(activity.prefix(2))),
            DailyDeltaGroup(id: "nutrition", title: "Nutrition", bullets: Array(nutrition.prefix(2))),
            DailyDeltaGroup(id: "recovery", title: "Recovery", bullets: Array(recovery.prefix(2))),
        ]
        .filter { $0.bullets.isEmpty == false }

        return DailyDelta(
            bullets: bullets,
            tldr: tldr,
            homePreview: homePreview,
            groups: groups
        )
    }
}

final class AdaptiveCoachFeatureStore {
    private enum Keys {
        static let savedMealsPrefix = "beu.savedMealsForLater."
        static let weeklyFocusPrefix = "beu.weeklyFocus."
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func savedMeals(userId: String) -> [SavedMealForLater] {
        decode([SavedMealForLater].self, forKey: Keys.savedMealsPrefix + userId) ?? []
    }

    func saveMeal(_ meal: NextBestMealSuggestion, userId: String) -> [SavedMealForLater] {
        var current = savedMeals(userId: userId)
        guard current.contains(where: { $0.id == meal.id || $0.name.caseInsensitiveCompare(meal.name) == .orderedSame }) == false else {
            return current
        }
        current.append(
            SavedMealForLater(
                id: meal.id,
                userId: userId,
                name: meal.name,
                mealType: meal.mealType,
                portion: meal.portion,
                estimatedCalories: meal.estimatedCalories,
                estimatedProteinGrams: meal.estimatedProteinGrams,
                savedAt: ISO8601DateFormatter().string(from: Date())
            )
        )
        encode(current, forKey: Keys.savedMealsPrefix + userId)
        return current
    }

    func weeklyFocus(userId: String) -> [String] {
        decode([String].self, forKey: Keys.weeklyFocusPrefix + userId) ?? []
    }

    func saveWeeklyFocus(_ chips: [String], userId: String) {
        encode(Array(chips.prefix(3)), forKey: Keys.weeklyFocusPrefix + userId)
    }

    func snapshot(userId: String) -> AdaptiveCoachFeatureSnapshot {
        AdaptiveCoachFeatureSnapshot(
            savedMeals: savedMeals(userId: userId),
            weeklyFocusChips: weeklyFocus(userId: userId)
        )
    }

    func restore(snapshot: AdaptiveCoachFeatureSnapshot?, userId: String) {
        if let savedMeals = snapshot?.savedMeals {
            encode(savedMeals, forKey: Keys.savedMealsPrefix + userId)
        } else {
            defaults.removeObject(forKey: Keys.savedMealsPrefix + userId)
        }

        if let weeklyFocusChips = snapshot?.weeklyFocusChips {
            encode(Array(weeklyFocusChips.prefix(3)), forKey: Keys.weeklyFocusPrefix + userId)
        } else {
            defaults.removeObject(forKey: Keys.weeklyFocusPrefix + userId)
        }
    }

    private func encode<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private func decode<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
