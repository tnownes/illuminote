import SwiftUI
import SceneKit

struct ForestSceneView: View {
    var body: some View {
        SceneView(
            scene: createForestScene(),
            options: []
        )
        .ignoresSafeArea()
    }
}

func createForestScene() -> SCNScene {
    let scene = SCNScene()

    // Use the provided image as a background
    scene.background.contents = UIImage(named: "forest-scene-reference-Design1.jpg")

    // MARK: - Water Surface with Ripple Animation
    // Create a flat water plane
    let waterPlane = SCNPlane(width: 10, height: 10)
    let waterMat = SCNMaterial()
    waterMat.diffuse.contents = UIColor.clear.withAlphaComponent(0.3)
    waterMat.normal.contents = UIImage(named: "waterNormal.png")
    waterMat.normal.wrapS = .repeat
    waterMat.normal.wrapT = .repeat
    waterMat.lightingModel = .physicallyBased
    waterMat.isDoubleSided = true
    waterPlane.materials = [waterMat]
    

    let waterNode = SCNNode(geometry: waterPlane)
    // Lay it horizontally
    waterNode.eulerAngles.x = -.pi / 2

    // Configurable water plane position (modify these values to move the plane)
    let waterPosX: Float = 0    // left/right offset
    let waterPosY: Float = 5   // up/down offset
    let waterPosZ: Float = -10   // depth offset
    waterNode.position = SCNVector3(waterPosX, waterPosY, waterPosZ)
    scene.rootNode.addChildNode(waterNode)

    // Animate UV offset for ripples
    let rippleDuration: TimeInterval = 6.0
    let rippleAction = SCNAction.repeatForever(
        SCNAction.customAction(duration: rippleDuration) { _, elapsedTime in
            let progress = Float(elapsedTime) / Float(rippleDuration)
            waterMat.normal.contentsTransform = SCNMatrix4MakeTranslation(progress, progress, 0)
            waterMat.normal.wrapS = .repeat
            waterMat.normal.wrapT = .repeat
        }
    )
    waterNode.runAction(rippleAction)

    // MARK: - Falling Leaves Particle System
    let leavesSystem = SCNParticleSystem()
    leavesSystem.particleImage = UIImage(named: "leaf.png")  // stylized leaf silhouette
    leavesSystem.birthRate = 10
    leavesSystem.particleLifeSpan = 18.0
    leavesSystem.particleSize = 0.03
    leavesSystem.particleColor = UIColor(red: 0.8, green: 0.6, blue: 0.3, alpha: 1.0)
    leavesSystem.particleColorVariation = SCNVector4(0.1, 0.1, 0, 0)
    leavesSystem.particleVelocity = -0.2  // downward motion
    leavesSystem.particleVelocityVariation = 0.1
    leavesSystem.spreadingAngle = 30
    leavesSystem.blendMode = .alpha
    leavesSystem.isLightingEnabled = true
    leavesSystem.emitterShape = SCNBox(width: 10, height: 0.1, length: 5, chamferRadius: 0)

    let leavesNode = SCNNode()
    leavesNode.position = SCNVector3(0, 5, -5)  // above the camera
    leavesNode.addParticleSystem(leavesSystem)
    scene.rootNode.addChildNode(leavesNode)

    return scene
}

#Preview {
    ForestSceneView()
}
