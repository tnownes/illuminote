import SwiftUI
import SceneKit

struct StainedGlassSceneView: View {
    var body: some View {
        SceneView(
            scene: createStainedGlassScene(),
            options: [.allowsCameraControl]
        )
        .ignoresSafeArea()
    }
}

/// Builds a SceneKit scene simulating a textured stained-glass window backlit by colored lights.
func createStainedGlassScene() -> SCNScene {
    let scene = SCNScene()

    // Load stained-glass image
    guard let bgImage = UIImage(named: "stained-glass-reference-design2") else {
        print("⚠️ Stained glass image not found in assets")
        return scene
    }
    let minIntensity: CGFloat = 0.8
    let maxIntensity: CGFloat = 2.5
    let upDuration: TimeInterval = 10.0
    let downDuration: TimeInterval = 16.0
    let delta = maxIntensity - minIntensity

    // Compute aspect ratio and plane dimensions
    let aspect = bgImage.size.width / bgImage.size.height
    let planeHeight: CGFloat = 6.0
    let planeWidth = planeHeight * aspect

    // Create a plane that preserves the image’s aspect ratio
    let plane = SCNPlane(width: planeWidth, height: planeHeight)
    let material = SCNMaterial()
    material.diffuse.contents = bgImage
    // Add emissive glow using the same image
    material.emission.contents = bgImage
    material.emission.intensity = 2.5
    material.lightingModel = .physicallyBased
    material.isDoubleSided = true
    plane.materials = [material]

    let planeNode = SCNNode(geometry: plane)
    // Position plane directly in front of the camera
    planeNode.position = SCNVector3(0, 0, -Float(planeHeight / 2))
    scene.rootNode.addChildNode(planeNode)

    // Parameterized living-light pulse
    let pulseUp = SCNAction.customAction(duration: upDuration) { _, elapsedTime in
        let t = CGFloat(elapsedTime)
        let progress = t / CGFloat(upDuration)
        let eased = sin(progress * .pi * 0.5)                // ease‑in curve
        material.emission.intensity = minIntensity + (delta * eased)
    }
    let pulseDown = SCNAction.customAction(duration: downDuration) { _, elapsedTime in
        let t = CGFloat(elapsedTime)
        material.emission.intensity = maxIntensity - (delta * (t / CGFloat(downDuration)))
    }
    let pulseSequence = SCNAction.sequence([pulseUp, pulseDown])
    let repeatPulse = SCNAction.repeatForever(pulseSequence)
    planeNode.runAction(repeatPulse)

    // (Optional) Existing lights will illuminate the emissive material appropriately

    return scene
}

#Preview {
    StainedGlassSceneView()
}
