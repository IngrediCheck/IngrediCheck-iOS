import Foundation
import SwiftUI

@Observable class PreferenceExamples {

    @MainActor var placeholder: String = inputPrompt
    @MainActor var preferences: [String] = []

    private var exampleIndex = 0
    private var charIndex = 0
    private var timer: Timer?
    
    public static let inputPrompt =
        "Add a Food Note"

    public static let examples = [
        "Avoid **Gluten**",
        "No **Palm oil** for me",
        "No **animal products**, but **eggs** & **dairy** are OK",
        "No **peanuts**, but other **nuts** are OK",
        "I don’t like **pine nuts**",
        "I can’t stand **garlic**"
    ]

    func startAnimatingExamples() {
        stopAnimatingExamples(isFocused: false)
        animateExamples()
    }

    func stopAnimatingExamples(isFocused: Bool) {
        timer?.invalidate()
        timer = nil
        exampleIndex = 0
        charIndex = 0
        updatePlaceholder(to: PreferenceExamples.inputPrompt)
    }

    private func animateExamples() {

        var currentExample: String

        if exampleIndex == PreferenceExamples.examples.count {
            exampleIndex = -1
        }
        
        if exampleIndex == -1 {
            currentExample = PreferenceExamples.inputPrompt
        } else {
            currentExample = PreferenceExamples.examples[exampleIndex]
        }

        if charIndex == 0 {
            Task { @MainActor in
                if exampleIndex > 0 {
                    preferences.append(PreferenceExamples.examples[exampleIndex-1])
                } else {
                    preferences = []
                }
            }
        }

        if charIndex <= currentExample.count {
            let index = currentExample.index(currentExample.startIndex, offsetBy: charIndex)
            charIndex += 1
            updatePlaceholder(to: String(currentExample[..<index]))
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
                self?.animateExamples()
            }
        } else {
            charIndex = 0
            exampleIndex += 1
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
                self?.animateExamples()
            }
        }
    }
    
    private func updatePlaceholder(to newPlaceholder: String) {
        Task { @MainActor in
            placeholder = newPlaceholder
        }
    }
}
