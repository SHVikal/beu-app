import Foundation

enum Goal: String, Codable, CaseIterable, Identifiable {
    case fatLoss
    case muscle
    case maintain
    case wellness

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fatLoss: return "Fat loss"
        case .muscle: return "Muscle build"
        case .maintain: return "Maintain"
        case .wellness: return "General wellness"
        }
    }

    var description: String {
        switch self {
        case .fatLoss: return "Slight calorie deficit, higher protein"
        case .muscle: return "Slight surplus, training-focused"
        case .maintain: return "Hold weight, balanced macros"
        case .wellness: return "Consistency over targets"
        }
    }
}

struct GoalPreset {
    let kcal: Int
    let protein: Int
    let waterLitres: Double
    let carbGuidance: String
    let label: String
    let direction: String
}

let GoalPresets: [Goal: GoalPreset] = [
    .fatLoss: GoalPreset(
        kcal: 1700,
        protein: 130,
        waterLitres: 2.4,
        carbGuidance: "lower carbs at dinner",
        label: "Fat loss",
        direction: "Slight deficit"
    ),
    .muscle: GoalPreset(
        kcal: 2450,
        protein: 160,
        waterLitres: 2.8,
        carbGuidance: "carbs around training",
        label: "Muscle build",
        direction: "Slight surplus"
    ),
    .maintain: GoalPreset(
        kcal: 2100,
        protein: 110,
        waterLitres: 2.5,
        carbGuidance: "balanced carbs",
        label: "Maintain",
        direction: "Maintain"
    ),
    .wellness: GoalPreset(
        kcal: 2000,
        protein: 100,
        waterLitres: 2.5,
        carbGuidance: "balanced carbs",
        label: "General wellness",
        direction: "Consistency"
    ),
]

enum Gender: String, Codable, CaseIterable, Identifiable {
    case female
    case male
    case nonBinary

    var id: String { rawValue }

    var title: String {
        switch self {
        case .female: return "Female"
        case .male: return "Male"
        case .nonBinary: return "Non-binary"
        }
    }
}

struct GoalConfig: Codable, Equatable {
    var goal: Goal
    var targetWeightKg: Int?
    var timeline: TimelinePreset
    var customYears: Int
}

enum DietPreference: String, Codable, CaseIterable, Identifiable {
    case indianVegetarian
    case vegetarian
    case vegan
    case noPreference

    var id: String { rawValue }

    var title: String {
        switch self {
        case .indianVegetarian:
            return "Indian vegetarian"
        case .vegetarian:
            return "Vegetarian"
        case .vegan:
            return "Vegan"
        case .noPreference:
            return "No preference"
        }
    }

    var apiValue: String {
        switch self {
        case .indianVegetarian:
            return "indian_vegetarian"
        case .vegetarian:
            return "vegetarian"
        case .vegan:
            return "vegan"
        case .noPreference:
            return "no_preference"
        }
    }
}

enum TimelinePreset: String, Codable, CaseIterable, Identifiable {
    case oneMonth = "1mo"
    case threeMonths = "3mo"
    case sixMonths = "6mo"
    case oneYear = "1yr"
    case custom = "custom"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .oneMonth: return "1 month"
        case .threeMonths: return "3 months"
        case .sixMonths: return "6 months"
        case .oneYear: return "1 year"
        case .custom: return "Custom"
        }
    }

    func displayValue(customYears: Int) -> String {
        switch self {
        case .oneMonth:
            return "1 month"
        case .threeMonths:
            return "3 months"
        case .sixMonths:
            return "6 months"
        case .oneYear:
            return "1 year"
        case .custom:
            return customYears == 1 ? "1 year" : "\(customYears) years"
        }
    }
}

enum Condition: String, Codable, CaseIterable, Identifiable {
    case pcos
    case diabetes
    case thyroidCondition
    case highBloodPressure
    case highCholesterol
    case anemiaLowIron
    case pregnancy
    case eatingDisorderHistory
    case none
    case preferNotToSay

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pcos: return "PCOS"
        case .diabetes: return "Diabetes"
        case .thyroidCondition: return "Thyroid condition"
        case .highBloodPressure: return "High blood pressure"
        case .highCholesterol: return "High cholesterol"
        case .anemiaLowIron: return "Anemia / low iron"
        case .pregnancy: return "Pregnancy"
        case .eatingDisorderHistory: return "Eating disorder history"
        case .none: return "None"
        case .preferNotToSay: return "Prefer not to say"
        }
    }
}
