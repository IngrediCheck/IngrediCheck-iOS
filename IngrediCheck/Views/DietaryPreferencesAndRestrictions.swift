//
//  DietaryPreferencesAndRestrictions.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 10/11/25.
//

import SwiftUI

struct DietaryPreferencesAndRestrictions: View {
    let isFamilyFlow: Bool
    @Environment(AppNavigationCoordinator.self) private var coordinator
    
    @State private var physicsController: PhysicsController?
    @State private var hasStarted = true
    
    private let categories: [ChipCategory] = [
        .init(title: "Mediterranean", icon: "🫒", gradientStart: UIColor(hex: "FFC978"), gradientEnd: UIColor(hex: "FF7A45"), isDummy: false),
        .init(title: "Dairy Free", icon: "🥛", gradientStart: UIColor(hex: "A894FF"), gradientEnd: UIColor(hex: "6A6CFF"), isDummy: false),
        .init(title: "Organic Only", icon: "🍃", gradientStart: UIColor(hex: "FFB5D0"), gradientEnd: UIColor(hex: "FF7EA8"), isDummy: false),
        .init(title: "Paleo", icon: "🥩", gradientStart: UIColor(hex: "B187FF"), gradientEnd: UIColor(hex: "6C6FFF"), isDummy: false),
        .init(title: "Low Sugar", icon: "🍓", gradientStart: UIColor(hex: "FFB47E"), gradientEnd: UIColor(hex: "FF6F6F"), isDummy: false),
        .init(title: "Vegetarian", icon: "🥦", gradientStart: UIColor(hex: "8EE58B"), gradientEnd: UIColor(hex: "4BC76C"), isDummy: false),
        .init(title: "Heart Health", icon: "🫀", gradientStart: UIColor(hex: "FFE59D"), gradientEnd: UIColor(hex: "FFC857"), isDummy: false),
        .init(title: "Molluscs", icon: "🐚", gradientStart: UIColor(hex: "FF9C7A"), gradientEnd: UIColor(hex: "FF5F63"), isDummy: false),
        .init(title: "High Protein", icon: "🍗", gradientStart: UIColor(hex: "7ED4FF"), gradientEnd: UIColor(hex: "528FFF"), isDummy: false),
        .init(title: "Celery", icon: "🥬", gradientStart: UIColor(hex: "FFAF8C"), gradientEnd: UIColor(hex: "FF6B6B"), isDummy: false),
        .init(title: "Low Fat", icon: "🥑", gradientStart: UIColor(hex: "8FE7F5"), gradientEnd: UIColor(hex: "4ECDE0"), isDummy: false),
        .init(title: "Gluten", icon: "🌾", gradientStart: UIColor(hex: "FFC488"), gradientEnd: UIColor(hex: "FF8F45"), isDummy: false),
        .init(title: "", icon: "", gradientStart: .clear, gradientEnd: .clear, isDummy: true)
    ]


    
    var body: some View {
        VStack {
            HStack {
                VStack(alignment:.leading, spacing: 0) {
                    Text("Fine-Tune")
                        .font(ManropeFont.extraBold.size(36))
                        .foregroundStyle(Color(hex: "D3D3D3"))
                    Text("   your Food")
                        .font(ManropeFont.extraBold.size(36))
                        .foregroundStyle(Color(hex: "D3D3D3"))
                    Text("Choices!!")
                        .font(ManropeFont.extraBold.size(36))
                        .foregroundStyle(Color(hex: "D3D3D3"))
                }
                .multilineTextAlignment(.leading)
                .padding(.top, 0)
            
                Spacer()
            }
            
            // Physics container - give it a specific height to work with
            PhysicsContainerView(
                categories: categories,
                hasStarted: $hasStarted,
                physicsController: $physicsController
            )
            .frame(maxWidth: .infinity)
            .layoutPriority(1) // Give it priority to expand
            
            // falling top edge
            LinearGradient(colors: [.black.opacity(0.4), .gray.opacity(0.5), .black.opacity(0.4)], startPoint: .leading, endPoint: .trailing)
                .blur(radius: 4)
                .frame(height: 2, alignment: .center)
                .padding(.bottom, 24)

            Spacer(minLength: 220)

        }
        .padding(.horizontal, 20)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            coordinator.setCanvasRoute(.dietaryPreferencesAndRestrictions(isFamilyFlow: isFamilyFlow))
        }
    }
}

#Preview {
    DietaryPreferencesAndRestrictions(isFamilyFlow: false)
        .environment(AppNavigationCoordinator())
}

struct ChipCategory {
    let title: String
    let icon: String
    let gradientStart: UIColor
    let gradientEnd: UIColor
    let isDummy: Bool
}

struct DietaryPreferencesSheetContent: View {
    let isFamilyFlow: Bool
    let letsGoPressed: () -> Void
    @Environment(FamilyStore.self) private var familyStore
    
    
    var body: some View {
        VStack(alignment: .center, spacing: 20) {
                
            VStack(alignment: .center, spacing: 8) {
                Text("Personalize your Choices")
                    .font(NunitoFont.bold.size(22))
                    .foregroundStyle(.grayScale150)
                
                Text("Let’s get started with you! We’ll create a profile just for you and guide you through personalized food tips.")
                    .multilineTextAlignment(.center)
                    .font(ManropeFont.medium.size(12))
                    .foregroundStyle(.grayScale100)
            }
            
//            Spacer()
            
            Button {
                letsGoPressed()
            } label: {
                GreenCapsule(title: "Let's Go!", takeFullWidth: false)
            }
            .padding(.top, isFamilyFlow ? 8 : 32)
        }
        .padding(.vertical, isFamilyFlow ? 16 : 32)
        .padding(.horizontal, 20)
        .frame(height: 263)
    }
}

#Preview {
    DietaryPreferencesSheetContent(isFamilyFlow: false) {
        
    }
}


// MARK: - Physics Container View
struct PhysicsContainerView: UIViewRepresentable {
    let categories: [ChipCategory]
    @Binding var hasStarted: Bool
    @Binding var physicsController: PhysicsController?
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = UIColor.clear
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if hasStarted && physicsController == nil {
            // Create physics controller when simulation should start
            let controller = PhysicsController(containerView: uiView, categories: categories)
            physicsController = controller
            
            // Wait a bit more for layout to complete, then start simulation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                controller.startSimulation()
            }
        }
        
        // Update bottom boundary when view size changes
        if let controller = physicsController {
            controller.updateBottomBoundary()
        }
    }
}

// MARK: - Physics Controller
class PhysicsController: NSObject, UIDynamicAnimatorDelegate, UICollisionBehaviorDelegate {
    private let containerView: UIView
    private let categories: [ChipCategory]
    private var animator: UIDynamicAnimator?
    private var gravity: UIGravityBehavior?
    private var collision: UICollisionBehavior?
    private var itemBehavior: UIDynamicItemBehavior?
    private var chips: [UIView] = []
    private var expectedChipCount: Int = 0
    private var createdChipCount: Int = 0
    private let hapticGenerator = UIImpactFeedbackGenerator(style: .light)
    private var lastHapticTime: Date = Date.distantPast
    private var hapticsEnabled: Bool = true
    private var hapticFeedbackCount: Int = 0
    private let maxHapticFeedbackCount: Int = 3
    private var notificationObserver: NSObjectProtocol?
    
    static let stopHapticsNotification = Notification.Name("StopDietaryPreferencesHaptics")
    
    init(containerView: UIView, categories: [ChipCategory]) {
        self.containerView = containerView
        self.categories = categories
        super.init()
        hapticGenerator.prepare()
        setupPhysics()
        setupNotificationObserver()
    }
    
    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func setupNotificationObserver() {
        notificationObserver = NotificationCenter.default.addObserver(
            forName: Self.stopHapticsNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.stopHaptics()
        }
    }
    
    func stopHaptics() {
        hapticsEnabled = false
        collision?.collisionDelegate = nil
    }
    
    private func setupPhysics() {
        // Create dynamic animator
        animator = UIDynamicAnimator(referenceView: containerView)
        animator?.delegate = self
        
        // Create gravity
        gravity = UIGravityBehavior()
        gravity?.magnitude = 1.35 // Stronger gravity to avoid mid-air stalls
        
        // Create collision behavior (manual boundaries; no top so items can fall in)
        collision = UICollisionBehavior()
        collision?.translatesReferenceBoundsIntoBoundary = false
        collision?.collisionDelegate = self
        
        // Create item behavior for bounciness and rotation
        itemBehavior = UIDynamicItemBehavior()
        itemBehavior?.elasticity = 0.35 // Slightly bouncier
        itemBehavior?.friction = 0.18 // Lower friction so stacks settle
        itemBehavior?.resistance = 0.02 // Very low air resistance so they keep moving
        itemBehavior?.angularResistance = 0.02
        itemBehavior?.allowsRotation = true // Allow rotation on impact
        
        // Add behaviors to animator
        if let gravity = gravity { animator?.addBehavior(gravity) }
        if let collision = collision { animator?.addBehavior(collision) }
        if let itemBehavior = itemBehavior { animator?.addBehavior(itemBehavior) }

        // Periodic nudge to prevent deadlocks in mid-air clusters
        let tick = UIDynamicBehavior()
        tick.action = { [weak self] in
            guard let self = self, let itemBehavior = self.itemBehavior else { return }
            let bottomY = self.containerView.bounds.height
            var anyAboveFloor = false
            var allResting = !self.chips.isEmpty
            for view in self.chips {
                let v = itemBehavior.linearVelocity(for: view)
                let speed = hypot(v.x, v.y)
                let aboveFloor = view.center.y < bottomY - 42
                if aboveFloor { anyAboveFloor = true }
                if speed > 6 || aboveFloor { allResting = false }
                // Nudge slow movers above the floor
                if speed < 12 && aboveFloor {
                    let pushY: CGFloat = 140
                    let pushX: CGFloat = CGFloat.random(in: -18...18)
                    itemBehavior.addLinearVelocity(CGPoint(x: pushX, y: pushY), for: view)
                }
            }
            // Keep simulation alive until all created and resting
            let allCreated = (self.createdChipCount >= self.expectedChipCount)
            let mustKeepRunning = !(allCreated && allResting)
            if mustKeepRunning, let animator = self.animator, animator.isRunning == false {
                self.gravity?.magnitude = 1.5
                if let first = self.chips.first {
                    itemBehavior.addLinearVelocity(CGPoint(x: 0, y: 8), for: first)
                }
            }
        }
        animator?.addBehavior(tick)
    }

    // MARK: - UIDynamicAnimatorDelegate
    func dynamicAnimatorDidPause(_ animator: UIDynamicAnimator) {
        // If animator paused but some items are still above the bottom, wake it with a tiny push
        let bottomY = containerView.bounds.height
        let stuck = chips.filter { $0.center.y < bottomY - 42 }
        guard !stuck.isEmpty, let itemBehavior = itemBehavior else { return }
        // Continuous push for a bit longer; enough to wake and keep moving
        let push = UIPushBehavior(items: stuck, mode: .continuous)
        push.pushDirection = CGVector(dx: 0, dy: 0.5)
        animator.addBehavior(push)
        // Also add a small linear velocity to the first to ensure motion
        if let first = stuck.first {
            itemBehavior.addLinearVelocity(CGPoint(x: 0, y: 40), for: first)
        }
        // Remove push after a short period
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            animator.removeBehavior(push)
        }
    }
    
    // MARK: - UICollisionBehaviorDelegate
    func collisionBehavior(_ behavior: UICollisionBehavior, beganContactFor item: UIDynamicItem, withBoundaryIdentifier identifier: NSCopying?, at p: CGPoint) {
        // Trigger mild haptic feedback when chip hits the bottom surface
        // Only if haptics are still enabled and we haven't exceeded the limit
        guard hapticsEnabled, hapticFeedbackCount < maxHapticFeedbackCount else { return }
        
        // Throttle to prevent too many rapid haptics
        if let boundaryIdentifier = identifier as? String, boundaryIdentifier == "bottomBoundary" {
            let now = Date()
            if now.timeIntervalSince(lastHapticTime) > 0.1 { // Throttle to max 10 per second
                hapticGenerator.impactOccurred(intensity: 0.5)
                lastHapticTime = now
                hapticFeedbackCount += 1
            }
        }
    }
    
    func startSimulation() {
        guard let gravity = gravity, let collision = collision else { return }
        
        // Update boundary first to ensure proper positioning
        updateBottomBoundary()
        
        // Create chips with staggered delays
        expectedChipCount = categories.count
        createdChipCount = 0
        for (index, category) in categories.enumerated() {
            var delay = Double.random(in: 0.05...0.2) + (Double(index) * 0.5)
            
            if index == expectedChipCount - 1 {
                delay = 6.0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.createChip(category: category, gravity: gravity, collision: collision)
            }
        }
    }
    
    private func createChip(category: ChipCategory, gravity: UIGravityBehavior, collision: UICollisionBehavior) {
        let chipView = createChipView(category: category)
        containerView.addSubview(chipView)
        chips.append(chipView)
        createdChipCount += 1
        
        // Random starting position ABOVE the screen
        let screenWidth = containerView.bounds.width > 0 ? containerView.bounds.width : 375
        let randomX = CGFloat.random(in: 60...(screenWidth - 60))
        let startY: CGFloat = -100 // Start well above the screen
        chipView.center = CGPoint(x: randomX, y: startY)
        
        // Force layout and compute best-fitting size from Auto Layout
        chipView.setNeedsLayout()
        chipView.layoutIfNeeded()
        let fitting = chipView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        let finalSize = CGSize(width: max(120, fitting.width), height: max(40, fitting.height))
        chipView.frame.size = finalSize
        applyGradient(to: chipView, for: category)
        
        // Add random initial rotation
        let randomRotation = CGFloat.random(in: -10...10) * .pi / 180
        chipView.transform = CGAffineTransform(rotationAngle: randomRotation)
        
        // Add to physics behaviors
        gravity.addItem(chipView)
        collision.addItem(chipView)
        itemBehavior?.addItem(chipView)
        
        // Add random angular velocity for spinning effect
        let randomAngularVelocity = CGFloat.random(in: -2...2)
        itemBehavior?.addAngularVelocity(randomAngularVelocity, for: chipView)

        // Kick-start motion so a late chip definitely begins to fall
        let initialVX = CGFloat.random(in: -40...40)
        let initialVY: CGFloat = 260
        itemBehavior?.addLinearVelocity(CGPoint(x: initialVX, y: initialVY), for: chipView)

        // If animator is currently paused, apply a short continuous push to wake it
        if let animator = animator, animator.isRunning == false {
            let push = UIPushBehavior(items: [chipView], mode: .continuous)
            push.pushDirection = CGVector(dx: 0, dy: 0.7)
            animator.addBehavior(push)
            // Keep push a bit longer so it doesn't stop immediately
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                animator.removeBehavior(push)
            }
        }

//        print("Created chip: \(category.title) at start position: \(chipView.center), container bounds: \(containerView.bounds)")
    }
    
    private func createChipView(category: ChipCategory) -> UIView {
        let chipView = UIView()
        chipView.backgroundColor = .clear
        chipView.layer.cornerRadius = 20
        chipView.layer.shadowColor = UIColor.black.cgColor
        chipView.layer.shadowOffset = CGSize(width: 0, height: 4)
        chipView.layer.shadowOpacity = 0.2
        chipView.layer.shadowRadius = 8
        
        // Create label
        let label = UILabel()
        label.text = category.title
        label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 1
        label.lineBreakMode = .byClipping // Prevent ellipsis
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.setContentHuggingPriority(.defaultLow, for: .vertical)
        
        // Create icon (emoji)
        let iconLabel = UILabel()
        iconLabel.text = category.icon
        iconLabel.font = UIFont.systemFont(ofSize: 18, weight: .regular)
        iconLabel.textAlignment = .center
        iconLabel.setContentHuggingPriority(.required, for: .horizontal)
        iconLabel.setContentHuggingPriority(.required, for: .vertical)
        
        // Create stack view
        var arrangedSubviews: [UIView] = []
        if !category.icon.isEmpty {
            arrangedSubviews.append(iconLabel)
        }
        arrangedSubviews.append(label)
        
        let stackView = UIStackView(arrangedSubviews: arrangedSubviews)
        stackView.axis = .horizontal
        stackView.spacing = category.icon.isEmpty ? 0 : 6
        stackView.alignment = .center
        stackView.distribution = .fill // Allow label to expand
        stackView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stackView.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        chipView.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Calculate text size to determine if we need more width
        let textSize = category.title.size(withAttributes: [
            .font: UIFont.systemFont(ofSize: 16, weight: .semibold)
        ])
        let iconWidth: CGFloat = category.icon.isEmpty ? 0 : 20
        let spacing: CGFloat = category.icon.isEmpty ? 0 : 8
        let padding: CGFloat = 32 // 16px on each side
        let minWidth: CGFloat = 80
        let requiredWidth = iconWidth + spacing + textSize.width + padding
        let finalWidth = max(minWidth, requiredWidth)
        
        // Dynamic sizing with calculated width
        NSLayoutConstraint.activate([
            // Stack view constraints with 16px padding
            stackView.leadingAnchor.constraint(equalTo: chipView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: chipView.trailingAnchor, constant: -16),
            stackView.topAnchor.constraint(equalTo: chipView.topAnchor, constant: 12),
            stackView.bottomAnchor.constraint(equalTo: chipView.bottomAnchor, constant: -12),
            
            // No explicit width constraint; allow intrinsic width to determine size
        ])
        
        // Set intrinsic content size - allow chip to expand
        chipView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        chipView.setContentHuggingPriority(.required, for: .vertical)
        chipView.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        if category.isDummy {
            chipView.alpha = 0.0
        }
        
        return chipView
    }
    
    func updateBottomBoundary() {
        guard let collision = collision, containerView.bounds.height > 0 else {
            print("Cannot update boundary - collision or container bounds not ready")
            return
        }
        
        // Remove existing custom boundaries if any
        collision.removeBoundary(withIdentifier: "bottomBoundary" as NSCopying)
        collision.removeBoundary(withIdentifier: "leftBoundary" as NSCopying)
        collision.removeBoundary(withIdentifier: "rightBoundary" as NSCopying)
        
        // Add boundaries: left, right, and bottom only (no top boundary)
        let width = containerView.bounds.width
        let height = containerView.bounds.height
        let bottomY = height
        
        print("Updating boundaries — bottomY: \(bottomY), width: \(width), height: \(height)")
        
        collision.addBoundary(withIdentifier: "leftBoundary" as NSCopying,
                              from: CGPoint(x: 0, y: -1000),
                              to:   CGPoint(x: 0, y: bottomY))
        
        collision.addBoundary(withIdentifier: "rightBoundary" as NSCopying,
                              from: CGPoint(x: width, y: -1000),
                              to:   CGPoint(x: width, y: bottomY))
        
        collision.addBoundary(withIdentifier: "bottomBoundary" as NSCopying,
                              from: CGPoint(x: 0, y: bottomY),
                              to:   CGPoint(x: width, y: bottomY))
    }

    private func applyGradient(to view: UIView, for category: ChipCategory) {
        let gradientLayer: CAGradientLayer
        if let existing = view.layer.sublayers?.first(where: { $0.name == "chipGradient" }) as? CAGradientLayer {
            gradientLayer = existing
        } else {
            gradientLayer = CAGradientLayer()
            gradientLayer.name = "chipGradient"
            gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
            gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
            view.layer.insertSublayer(gradientLayer, at: 0)
        }
        gradientLayer.colors = [category.gradientStart.cgColor, category.gradientEnd.cgColor]
        gradientLayer.frame = view.bounds
        gradientLayer.cornerRadius = view.layer.cornerRadius
    }
}

private extension UIColor {
    convenience init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if hexSanitized.count == 6 {
            hexSanitized = "FF" + hexSanitized
        }
        
        var int: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&int)
        
        let a, r, g, b: UInt64
        switch hexSanitized.count {
        case 8:
            a = (int & 0xFF000000) >> 24
            r = (int & 0x00FF0000) >> 16
            g = (int & 0x0000FF00) >> 8
            b = int & 0x000000FF
        default:
            a = 255; r = 255; g = 255; b = 255
        }
        
        self.init(red: CGFloat(r) / 255,
                  green: CGFloat(g) / 255,
                  blue: CGFloat(b) / 255,
                  alpha: CGFloat(a) / 255)
    }
}
