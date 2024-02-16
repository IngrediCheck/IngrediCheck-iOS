import Foundation

@Observable class PreferenceExamples {

    var placeholder: String = .init()
    var preferences: [String] = []

    private var exampleIndex = 0
    private var charIndex = 0
    private var timer: Timer?
    
    private let examples = [
        "Add your preferences here",
        "Avoid Gluten",
        "No Palm oil for me",
        "No animal products, but eggs & dairy are ok",
        "No peanuts but other nuts are ok",
        "I don't like pine nuts",
        "I can't stand garlic"
    ]

    func startAnimatingExamples() {
        stopAnimatingExamples()
        animateExamples()
    }

    func stopAnimatingExamples() {
        timer?.invalidate()
        timer = nil
        placeholder = .init()
        exampleIndex = 0
        charIndex = 0
    }

    private func animateExamples() {
        if exampleIndex >= examples.count {
            exampleIndex = 0
        }
        
        if charIndex == 0 {
            if exampleIndex > 1 {
                preferences.append(examples[exampleIndex-1])
            } else {
                preferences = []
            }
        }
        
        let example = examples[exampleIndex]

        if charIndex <= example.count {
            let index = example.index(example.startIndex, offsetBy: charIndex)
            placeholder = String(example[..<index])
            charIndex += 1
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
                self?.animateExamples()
            }
        } else {
            print("next example in 1s")
            charIndex = 0
            exampleIndex += 1
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
                self?.animateExamples()
            }
        }
    }
}
