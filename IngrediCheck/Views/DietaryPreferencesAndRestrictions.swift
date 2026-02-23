//
//  DietaryPreferencesAndRestrictions.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 10/11/25.
//

import SwiftUI
import SpriteKit

struct DietaryPreferencesAndRestrictions: View {
    let isFamilyFlow: Bool
    @Environment(AppNavigationCoordinator.self) private var coordinator

    @State private var scene: PhysicsScene?

    private func makeScene(size: CGSize) -> SKScene {
        if let existing = scene { return existing }
        let newScene = PhysicsScene(size: size)
        newScene.scaleMode = .aspectFit
        newScene.backgroundColor = .clear
        DispatchQueue.main.async { scene = newScene }
        return newScene
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                GeometryReader { geo in
                    SpriteView(scene: makeScene(size: geo.size), options: [.allowsTransparency])
                        .ignoresSafeArea()
                }

                HStack {
                    VStack(alignment:.leading, spacing: 0) {
                        Text("Fine-Tune")
                            .font(ManropeFont.extraBold.size(36))
                            .foregroundStyle(Color(hex: "D3D3D3"))
                        Text("   your Food")
                            .font(ManropeFont.extraBold.size(36))
                            .foregroundStyle(Color(hex: "D3D3D3"))
                        Text("Choices!")
                            .font(ManropeFont.extraBold.size(36))
                            .foregroundStyle(Color(hex: "D3D3D3"))
                    }
                    .multilineTextAlignment(.leading)

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 39)
                .allowsHitTesting(false)
            }
            .ignoresSafeArea(edges: .top)
            .layoutPriority(1)

            // falling top edge
            LinearGradient(colors: [.black.opacity(0.4), .gray.opacity(0.5), .black.opacity(0.4)], startPoint: .leading, endPoint: .trailing)
                .blur(radius: 4)
                .frame(height: 2, alignment: .center)
                .padding(.horizontal, 20)
                .padding(.bottom, 24)

            Spacer(minLength: 220)
        }
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

                Text("Let's get started with you! We'll create a profile just for you and guide you through personalized food tips.")
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

// MARK: - SpriteKit Scene
class PhysicsScene: SKScene {

    static let stopHapticsNotification = Notification.Name("StopDietaryPreferencesHaptics")

    struct ChipData {
        let title: String
        let icon: String
        let gradientStart: UIColor
        let gradientEnd: UIColor
    }

    let chips: [ChipData] = [
        ChipData(title: "Mediterranean", icon: "\u{1FAD2}", gradientStart: UIColor(hex: "FFC978"), gradientEnd: UIColor(hex: "FF7A45")),
        ChipData(title: "Dairy Free", icon: "\u{1F95B}", gradientStart: UIColor(hex: "A894FF"), gradientEnd: UIColor(hex: "6A6CFF")),
        ChipData(title: "Organic Only", icon: "\u{1F343}", gradientStart: UIColor(hex: "FFB5D0"), gradientEnd: UIColor(hex: "FF7EA8")),
        ChipData(title: "Paleo", icon: "\u{1F969}", gradientStart: UIColor(hex: "B187FF"), gradientEnd: UIColor(hex: "6C6FFF")),
        ChipData(title: "Low Sugar", icon: "\u{1F353}", gradientStart: UIColor(hex: "FFB47E"), gradientEnd: UIColor(hex: "FF6F6F")),
        ChipData(title: "Vegetarian", icon: "\u{1F966}", gradientStart: UIColor(hex: "8EE58B"), gradientEnd: UIColor(hex: "4BC76C")),
        ChipData(title: "Heart Health", icon: "\u{1FAC0}", gradientStart: UIColor(hex: "FFE59D"), gradientEnd: UIColor(hex: "FFC857")),
        ChipData(title: "Molluscs", icon: "\u{1F41A}", gradientStart: UIColor(hex: "FF9C7A"), gradientEnd: UIColor(hex: "FF5F63")),
        ChipData(title: "High Protein", icon: "\u{1F357}", gradientStart: UIColor(hex: "7ED4FF"), gradientEnd: UIColor(hex: "528FFF")),
        ChipData(title: "Celery", icon: "\u{1F96C}", gradientStart: UIColor(hex: "FFAF8C"), gradientEnd: UIColor(hex: "FF6B6B")),
        ChipData(title: "Low Fat", icon: "\u{1F951}", gradientStart: UIColor(hex: "8FE7F5"), gradientEnd: UIColor(hex: "4ECDE0")),
        ChipData(title: "Gluten", icon: "\u{1F33E}", gradientStart: UIColor(hex: "FFC488"), gradientEnd: UIColor(hex: "FF8F45"))
    ]

    var touchAnchor = SKNode()
    var activeJoint: SKPhysicsJointSpring?
    var draggedNode: SKNode?

    override func didMove(to view: SKView) {
        physicsWorld.gravity = CGVector(dx: 0, dy: -6.0)

        setupBoundaries()
        setupTouchAnchor()
        spawnChips()
    }

    private func setupBoundaries() {
        let extendedBoundary = CGRect(x: 0, y: 0, width: size.width, height: size.height + 2000)
        let frameBody = SKPhysicsBody(edgeLoopFrom: extendedBoundary)
        frameBody.friction = 0.5
        self.physicsBody = frameBody
    }

    private func setupTouchAnchor() {
        touchAnchor.physicsBody = SKPhysicsBody(circleOfRadius: 1)
        touchAnchor.physicsBody?.isDynamic = false
        addChild(touchAnchor)
    }

    private func spawnChips() {
        for (index, data) in chips.enumerated() {
            let randomX = CGFloat.random(in: 60...(size.width - 60))
            let spawnY = size.height + 100 + CGFloat(index * 150)
            let rotation = CGFloat.random(in: -0.25...0.25)

            let chipNode = createChipNode(data: data)
            chipNode.position = CGPoint(x: randomX, y: spawnY)
            chipNode.zRotation = rotation

            addChild(chipNode)
        }
    }

    private func createChipNode(data: ChipData) -> SKNode {
        let chipTexture = renderChipTexture(data: data)
        let chipSize = chipTexture.size()

        let sprite = SKSpriteNode(texture: chipTexture)
        sprite.name = "chip"

        // Shadow node with blur
        let shadowEffect = SKEffectNode()
        shadowEffect.filter = CIFilter(name: "CIGaussianBlur", parameters: ["inputRadius": 8.0])
        shadowEffect.shouldEnableEffects = true
        shadowEffect.position = CGPoint(x: 0, y: -4)
        shadowEffect.zPosition = -1

        let shadowSprite = SKSpriteNode(texture: chipTexture)
        shadowSprite.color = .black
        shadowSprite.colorBlendFactor = 1.0
        shadowSprite.alpha = 0.2
        shadowEffect.addChild(shadowSprite)
        sprite.addChild(shadowEffect)

        let body = SKPhysicsBody(polygonFrom: createRoundedPath(size: chipSize, radius: 20))
        body.restitution = 0.35
        body.friction = 0.1
        body.mass = chipSize.width / 100
        sprite.physicsBody = body

        return sprite
    }

    private func renderChipTexture(data: ChipData) -> SKTexture {
        let iconFont = UIFont.systemFont(ofSize: 18)
        let titleFont = UIFont.systemFont(ofSize: 16, weight: .semibold)

        let iconAttrs: [NSAttributedString.Key: Any] = [.font: iconFont]
        let titleAttrs: [NSAttributedString.Key: Any] = [.font: titleFont, .foregroundColor: UIColor.white]

        let iconSize = (data.icon as NSString).size(withAttributes: iconAttrs)
        let titleSize = (data.title as NSString).size(withAttributes: titleAttrs)

        let horizontalPadding: CGFloat = 16
        let spacing: CGFloat = 6
        let chipHeight: CGFloat = 44
        let chipWidth = horizontalPadding + iconSize.width + spacing + titleSize.width + horizontalPadding

        let chipSize = CGSize(width: ceil(chipWidth), height: chipHeight)
        let cornerRadius: CGFloat = 20

        let renderer = UIGraphicsImageRenderer(size: chipSize)
        let image = renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: chipSize)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
            path.addClip()

            // Draw gradient
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let cgColors = [data.gradientStart.cgColor, data.gradientEnd.cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: colorSpace, colors: cgColors, locations: [0, 1]) {
                ctx.cgContext.drawLinearGradient(gradient,
                                                 start: CGPoint(x: 0, y: 0),
                                                 end: CGPoint(x: chipSize.width, y: 0),
                                                 options: [])
            }

            // Draw icon (emoji) - vertically centered
            let iconY = (chipHeight - iconSize.height) / 2
            let iconRect = CGRect(x: horizontalPadding, y: iconY, width: iconSize.width, height: iconSize.height)
            (data.icon as NSString).draw(in: iconRect, withAttributes: iconAttrs)

            // Draw title text - vertically centered
            let titleY = (chipHeight - titleSize.height) / 2
            let titleRect = CGRect(x: horizontalPadding + iconSize.width + spacing, y: titleY, width: titleSize.width, height: titleSize.height)
            (data.title as NSString).draw(in: titleRect, withAttributes: titleAttrs)
        }

        return SKTexture(image: image)
    }

    // MARK: - Interactivity (Dragging & Flicking)

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        let touchedNodes = nodes(at: location)
        if let chip = touchedNodes.first(where: { $0.name == "chip" }) {
            draggedNode = chip
            touchAnchor.position = location

            let joint = SKPhysicsJointSpring.joint(withBodyA: touchAnchor.physicsBody!,
                                                   bodyB: chip.physicsBody!,
                                                   anchorA: location,
                                                   anchorB: location)
            joint.damping = 0.1
            joint.frequency = 4.0
            physicsWorld.add(joint)
            activeJoint = joint
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, draggedNode != nil else { return }
        touchAnchor.position = touch.location(in: self)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        releaseDrag()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        releaseDrag()
    }

    private func releaseDrag() {
        if let joint = activeJoint {
            physicsWorld.remove(joint)
            activeJoint = nil
            draggedNode = nil
        }
    }

    // MARK: - Helpers

    private func createRoundedPath(size: CGSize, radius: CGFloat) -> CGPath {
        let rect = CGRect(origin: CGPoint(x: -size.width / 2, y: -size.height / 2), size: size)
        return UIBezierPath(roundedRect: rect, cornerRadius: radius).cgPath
    }

}

private extension UIColor {
    convenience init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
