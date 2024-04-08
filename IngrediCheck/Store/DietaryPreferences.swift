import SwiftUI
import Foundation

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
        Task {
            await populatePreferences()
        }
    }
    
    @MainActor var asString: String {
        preferences
            .map { preference in
                preference.text
            }
            .joined(separator: "\n")
    }
    
    private func populatePreferences() async {
        let newPreferences = try? await webService.getDietaryPreferences()
        if let newPreferences {
            await MainActor.run {
                self.preferences = newPreferences
            }
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
            } catch {
                // ??
            }
        }
    }
    
    @MainActor public func startEditPreference(preference: DTO.DietaryPreference) {
        indexOfCurrentlyEditedPreference =
            preferences.firstIndex(of: preference)!
        preferences.remove(at: indexOfCurrentlyEditedPreference)
        inEditPreference = preference
        newPreferenceText = preference.text
    }
    
    @MainActor public func cancelInEditPreference() {
        if let inEditPreference {
            preferences.insert(inEditPreference, at: indexOfCurrentlyEditedPreference)
            newPreferenceText = ""
            indexOfCurrentlyEditedPreference = 0
            self.inEditPreference = nil
            clientActivityId = UUID().uuidString
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
