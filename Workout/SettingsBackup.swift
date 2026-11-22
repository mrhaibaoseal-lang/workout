import Foundation
import Security

/// Mirrors the user's settings into the Keychain. iOS keeps Keychain items when an
/// app is deleted, so a reinstall signed with the same certificate and bundle ID
/// gets its equipment, loads, timetable and so on back without onboarding again.
enum SettingsBackup {
    /// Every UserDefaults key that is a user choice. Calendar access is left out:
    /// that permission is granted per install, so the toggle starts off again.
    static let keys: [String] = [
        Keys.onboarded, Keys.equipment, Keys.startDate, Keys.weeklyGoal, Keys.increment,
        Keys.maxDumbbell, Keys.maxBarbell, Keys.reminderOn, Keys.reminderWeekdays,
        Keys.reminderMinutes, Keys.commuteSchool, Keys.commuteWork, Keys.earliestHour,
        Keys.preferredHour, Keys.latestHour, Keys.reminderLead, Keys.tiredHours,
        Keys.place, Keys.schemes, Keys.limitBarbell, Keys.kits, Keys.autoWarmup, Keys.height,
        Keys.customExercises, Keys.customPrograms, Keys.activeProgram, Keys.customInAutoPick, Keys.autoSuperset,
        Keys.tempos, Keys.intervalSetups,
        Keys.avoidExercises, Keys.painLog, Keys.patternShift, Keys.pinnedV023,
        Keys.repCeiling, Keys.extraSet, Keys.tempRange,
        Keys.muscleFeedback, Keys.muscleSetAdjust, Keys.volumeReviews, Keys.volumeReviewedBlock, Keys.weeklySummarySeen,
        Keys.builtInProgram, Keys.weekMerge, Keys.weekMergeDismissed,
        Keys.deloadOverrides, Keys.deloadAskedWeek, Keys.trainingLevel, Keys.graduationSnooze, Keys.graduatedAt,
        Keys.weakSide, Keys.weakExtra, Keys.weakExtraSnooze,
        ClassStore.key, EventStore.key,
    ]

    private static let service = "com.mrhaibaoseal.workout.settings"
    private static let account = "backup"
    private static var observer: NSObjectProtocol?

    /// Call once at launch, before any view reads @AppStorage.
    static func start() {
        restoreIfFresh()
        save()
        observer = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { _ in save() }
    }

    /// A fresh install has no `onboarded` value; fill it from the Keychain copy.
    private static func restoreIfFresh() {
        let d = UserDefaults.standard
        guard d.object(forKey: Keys.onboarded) == nil, let saved = load() else { return }
        for key in keys {
            if let value = saved[key] { d.set(value, forKey: key) }
        }
    }

    private static var lastSaved: Data?

    static func save() {
        let d = UserDefaults.standard
        // Nothing worth keeping until onboarding is done; also avoids overwriting a
        // good backup with blank defaults.
        guard d.bool(forKey: Keys.onboarded) else { return }
        var dict: [String: Any] = [:]
        for key in keys {
            if let value = d.object(forKey: key) { dict[key] = value }
        }
        guard let data = try? PropertyListSerialization.data(fromPropertyList: dict, format: .binary, options: 0),
              data != lastSaved else { return }
        if write(data) { lastSaved = data }
    }

    private static func load() -> [String: Any]? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data else { return nil }
        return (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any]
    }

    @discardableResult
    private static func write(_ data: Data) -> Bool {
        let attrs: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let status = SecItemUpdate(baseQuery as CFDictionary, attrs as CFDictionary)
        if status == errSecSuccess { return true }
        guard status == errSecItemNotFound else { return false }
        let add = baseQuery.merging(attrs) { $1 }
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
