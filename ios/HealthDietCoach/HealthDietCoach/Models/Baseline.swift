import Foundation

struct Baseline: Codable, Equatable {
    var name: String
    var age: Int
    var gender: Gender
    var heightCm: Int
    var weightKg: Int
    var dietPreference: DietPreference
    var medical: [Condition]
    var medicalNotes: String
    var supplements: [Supplement]

    enum CodingKeys: String, CodingKey {
        case name
        case age
        case gender
        case heightCm
        case weightKg
        case dietPreference
        case medical
        case medicalNotes
        case supplements
    }

    init(
        name: String,
        age: Int,
        gender: Gender,
        heightCm: Int,
        weightKg: Int,
        dietPreference: DietPreference = .indianVegetarian,
        medical: [Condition],
        medicalNotes: String,
        supplements: [Supplement]
    ) {
        self.name = name
        self.age = age
        self.gender = gender
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.dietPreference = dietPreference
        self.medical = medical
        self.medicalNotes = medicalNotes
        self.supplements = supplements
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        age = try container.decode(Int.self, forKey: .age)
        gender = try container.decode(Gender.self, forKey: .gender)
        heightCm = try container.decode(Int.self, forKey: .heightCm)
        weightKg = try container.decode(Int.self, forKey: .weightKg)
        dietPreference = try container.decodeIfPresent(DietPreference.self, forKey: .dietPreference) ?? .indianVegetarian
        medical = try container.decode([Condition].self, forKey: .medical)
        medicalNotes = try container.decode(String.self, forKey: .medicalNotes)
        supplements = try container.decode([Supplement].self, forKey: .supplements)
    }
}

extension Baseline {
    static let prototype = Baseline(
        name: "Aria",
        age: 30,
        gender: .female,
        heightCm: 165,
        weightKg: 72,
        dietPreference: .indianVegetarian,
        medical: [.pcos],
        medicalNotes: "",
        supplements: [
            Supplement(
                id: UUID().uuidString,
                userId: "local-user",
                name: "Myo-Inositol",
                dosage: "2g",
                frequency: .daily,
                timeOfDay: .morning,
                notes: nil,
                isActive: true,
                createdAt: Date(),
                updatedAt: Date()
            ),
            Supplement(
                id: UUID().uuidString,
                userId: "local-user",
                name: "Vitamin D3",
                dosage: "2000 IU",
                frequency: .daily,
                timeOfDay: .evening,
                notes: nil,
                isActive: true,
                createdAt: Date(),
                updatedAt: Date()
            ),
        ]
    )
}
