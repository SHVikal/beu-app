import Foundation

@MainActor
final class GoalStore: ObservableObject {
    @Published private(set) var goalConfig: GoalConfig?

    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("BeU", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        fileURL = folder.appendingPathComponent("goal.json")
        load()
    }

    func load() {
        guard let data = try? Data(contentsOf: fileURL) else {
            self.goalConfig = nil
            return
        }

        if let goalConfig = try? decoder.decode(GoalConfig.self, from: data) {
            self.goalConfig = clamped(goalConfig)
            return
        }

        guard let legacy = try? decoder.decode(LegacyGoalConfig.self, from: data) else {
            self.goalConfig = nil
            return
        }

        let migrated = GoalConfig(
            goal: legacy.goal,
            targetWeightKg: legacy.targetWeightKg,
            timeline: migrateTimeline(from: legacy.timelineWeeks),
            customYears: 2
        )
        save(migrated)
    }

    func save(_ goalConfig: GoalConfig) {
        let goalConfig = clamped(goalConfig)
        if let data = try? encoder.encode(goalConfig) {
            try? data.write(to: fileURL, options: .atomic)
            self.goalConfig = goalConfig
        }
    }

    private func clamped(_ goalConfig: GoalConfig) -> GoalConfig {
        var copy = goalConfig
        copy.customYears = min(max(copy.customYears, 1), 10)
        return copy
    }

    private func migrateTimeline(from legacyWeeks: Int?) -> TimelinePreset {
        switch legacyWeeks {
        case 4:
            return .oneMonth
        case 8, 12:
            return .threeMonths
        default:
            return .threeMonths
        }
    }

    private struct LegacyGoalConfig: Codable {
        var goal: Goal
        var targetWeightKg: Int?
        var timelineWeeks: Int?
    }
}

@MainActor
final class WaterProgressStore: ObservableObject {
    @Published private(set) var dailyHydrationMl: Int = 0

    private let defaults: UserDefaults
    private let dateFormatter = ISODateOnlyFormatter.shared
    private let maxHydrationMl = 4000

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadToday()
    }

    var litresToday: Double {
        Double(dailyHydrationMl) / 1000
    }

    func loadToday() {
        dailyHydrationMl = min(max(defaults.integer(forKey: key(for: Date())), 0), maxHydrationMl)
    }

    @discardableResult
    func add100Millilitres() -> Bool {
        guard dailyHydrationMl < maxHydrationMl else { return false }
        dailyHydrationMl = min(dailyHydrationMl + 100, maxHydrationMl)
        defaults.set(dailyHydrationMl, forKey: key(for: Date()))
        return true
    }

    func overwriteToday(millilitres: Int) {
        dailyHydrationMl = min(max(millilitres, 0), maxHydrationMl)
        defaults.set(dailyHydrationMl, forKey: key(for: Date()))
    }

    private func key(for date: Date) -> String {
        "beu_water_\(dateFormatter.string(from: date))"
    }
}

enum ISODateOnlyFormatter {
    static let shared: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
