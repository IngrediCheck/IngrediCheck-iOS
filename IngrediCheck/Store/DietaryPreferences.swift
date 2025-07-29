import SwiftUI
import Foundation

fileprivate let DietaryPreferencesKey = "DietaryPreferences"

extension UserDefaults {

    static func setDietaryPreferences(_ preferences: [DTO.DietaryPreference]) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(preferences) {
            UserDefaults.standard.set(encoded, forKey: DietaryPreferencesKey)
        }
    }

    static func restoreDietaryPreferences() -> [DTO.DietaryPreference] {
        if let savedPreferences = UserDefaults.standard.object(forKey: DietaryPreferencesKey) as? Data {
            let decoder = JSONDecoder()
            if let loadedPreferences = try? decoder.decode([DTO.DietaryPreference].self, from: savedPreferences) {
                return loadedPreferences
            }
        }
        return []
    }
    
    static func deleteDietaryPreferences() {
        UserDefaults.standard.removeObject(forKey: DietaryPreferencesKey)
    }
}

@Observable class DietaryPreferences {

    @MainActor var preferences: [DTO.DietaryPreference] = []
    @MainActor var newPreferenceText: String = ""
    @MainActor var validationResult: ValidationResult = .idle

    @MainActor private var inEditPreference: DTO.DietaryPreference? = nil
    @MainActor private var indexOfCurrentlyEditedPreference: Int = 0
    @MainActor private var clientActivityId: String = UUID().uuidString

    // TODO: Find a way to not have to create a new WebService instance here.
    private let webService = WebService()
    private var task: Task<(), Never>? = nil

    init() {
        loadPreferences()
    }
    
    @MainActor var asString: String {
        preferences.isEmpty
        ?
        "None"
        :
            preferences
                .map { preference in
                    preference.text
                }
                .joined(separator: "\n")
    }
    
    private func loadPreferences() {
        DispatchQueue.main.async {
            self.preferences = UserDefaults.restoreDietaryPreferences()
        }
    }

    public func refreshPreferences() {
        Task {
            await self.uploadGrandFatheredPreferences()
            let newPreferences = try? await self.webService.getDietaryPreferences()
            if let newPreferences {
                await MainActor.run {
                    self.preferences = newPreferences
                }
                UserDefaults.setDietaryPreferences(newPreferences)
            }
        }
    }
    
    private func uploadGrandFatheredPreferences() async {
        let preferencesKey = "userPreferences"
        let preferences = UserDefaults.standard.stringArray(forKey: preferencesKey) ?? []
        do {
            try await webService.uploadGrandFatheredPreferences(preferences.reversed())
            UserDefaults.standard.removeObject(forKey: preferencesKey)
        } catch {
            // ??
        }
    }
    
    @MainActor public func clearNewPreferenceText() {
        newPreferenceText = ""
        validationResult = .idle
        task?.cancel()
    }
    
    public func deletePreference(preference: DTO.DietaryPreference) {
        Task {
            do {
                try await webService.deleteDietaryPreference(
                    clientActivityId: clientActivityId,
                    id: preference.id
                )
                await MainActor.run {
                    preferences.removeAll { $0 == preference }
                    clientActivityId = UUID().uuidString
                }
                UserDefaults.setDietaryPreferences(await preferences)
            } catch {
                // ??
            }
        }
    }
    
    public func clearAll() {
        UserDefaults.deleteDietaryPreferences()
    }
    
    @MainActor public func startEditPreference(preference: DTO.DietaryPreference) {
        indexOfCurrentlyEditedPreference =
            preferences.firstIndex(of: preference)!
        preferences.remove(at: indexOfCurrentlyEditedPreference)
        inEditPreference = preference
        newPreferenceText = preference.text
        Task {
            UserDefaults.setDietaryPreferences(preferences)
        }
    }
    
    @MainActor public func cancelInEditPreference() {
        if let inEditPreference {
            preferences.insert(inEditPreference, at: indexOfCurrentlyEditedPreference)
            newPreferenceText = ""
            indexOfCurrentlyEditedPreference = 0
            self.inEditPreference = nil
            clientActivityId = UUID().uuidString
            Task {
                UserDefaults.setDietaryPreferences(preferences)
            }
        }
    }
    
    @MainActor public func inputActive() {
        validationResult = .idle
        task?.cancel()
    }
    
    @MainActor public func inputComplete() {
        if !newPreferenceText.isEmpty {
            validationResult = .validating
            task = Task {
                await validateInput(newPreferenceText)
            }
        }
    }

    private func validateInput(_ input: String) async {
        do {
            let validationResult =
                try await webService.addOrEditDietaryPreference(
                    clientActivityId: clientActivityId,
                    preferenceText: input,
                    id: inEditPreference.map { $0.id }
                )

            DispatchQueue.main.async {
                switch validationResult {
                case .failure(let explanation):
                    withAnimation {
                        self.validationResult = .failure(explanation)
                    }
                case .success(let newPreference):
                    withAnimation {
                        self.validationResult = .success
                        self.preferences.insert(
                            newPreference,
                            at: self.indexOfCurrentlyEditedPreference
                        )
                        self.newPreferenceText = ""
                    }
                    self.indexOfCurrentlyEditedPreference = 0
                    self.inEditPreference = nil
                    self.clientActivityId = UUID().uuidString
                    Task {
                        UserDefaults.setDietaryPreferences(self.preferences)
                    }
                }
            }
        } catch {
            if error is CancellationError {
                print("Task was cancelled")
            } else {
                DispatchQueue.main.async {
                    withAnimation {
                        self.validationResult = .failure("Something went wrong. Please try again later.")
                    }
                }
            }
        }
    }
}
