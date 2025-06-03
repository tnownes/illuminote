import SwiftUI
import SceneKit
import CoreImage
import CoreImage.CIFilterBuiltins

struct RainSceneView: View {
    var body: some View {
        SceneView(
            scene: createRainScene(),
            options: []
        )
        .ignoresSafeArea()
    }
}

func createRainScene() -> SCNScene {
    let scene = SCNScene()

    // Set a background image for the rainy window effect
    scene.background.contents = UIImage(named: "Rain-Reference-Design2.jpg")

    // Add animated raindrops using a particle system
    let rain = SCNParticleSystem()
    rain.particleImage = UIImage(named: "spark.png")
    rain.birthRate = 30
    rain.particleLifeSpan = 3.0
    rain.particleSize = 0.03
    rain.emitterShape = SCNBox(width: 5, height: 0.5, length: 9, chamferRadius: 0)
    rain.particleColor = UIColor.white.withAlphaComponent(0.15)
    rain.particleVelocity = 1.2
    rain.particleVelocityVariation = 0.7
    rain.acceleration = SCNVector3(0, -9.8, 0)
    rain.blendMode = .additive

    let rainNode = SCNNode()
    rainNode.position = SCNVector3(0, 7, 0)
    rainNode.addParticleSystem(rain)
    scene.rootNode.addChildNode(rainNode)

    // Procedural water streak overlay
    let overlay = SCNPlane(width: 4, height: 6)
    let overlayMaterial = SCNMaterial()
    // Generate at runtime: use 512x768 or match aspect
    let texSize = CGSize(width: 512, height: 768)
    overlayMaterial.diffuse.contents = generateStreakTexture(size: texSize)
    overlayMaterial.diffuse.wrapT = .repeat
    overlayMaterial.isDoubleSided = true
    overlayMaterial.transparency = 0.3
    // Option 1: Physically-based lighting model for overlay
    overlayMaterial.lightingModel = .physicallyBased
    overlay.materials = [overlayMaterial]

    let overlayNode = SCNNode(geometry: overlay)
    overlayNode.position = SCNVector3(0, 1.5, 1.5)
    scene.rootNode.addChildNode(overlayNode)

    // Option 2: Particle highlights to catch the streaks
    let highlightSystem = SCNParticleSystem()
    highlightSystem.particleImage = UIImage(named: "spark.png")
    highlightSystem.birthRate = 3
    highlightSystem.particleLifeSpan = 0.19
    highlightSystem.particleSize = 0.04
    highlightSystem.particleColor = UIColor.white.withAlphaComponent(0.1)
    highlightSystem.blendMode = .additive
    highlightSystem.isLightingEnabled = false
    highlightSystem.emitterShape = overlay  // distribute across the plane

    let highlightNode = SCNNode()
    highlightNode.position = overlayNode.position
    highlightNode.addParticleSystem(highlightSystem)
    scene.rootNode.addChildNode(highlightNode)

    // Scroll texture with existing SCNAction
    let scrollDuration: TimeInterval = 10.0
    let scrollAction = SCNAction.repeatForever(
        SCNAction.customAction(duration: scrollDuration) { _, elapsed in
            let progress = Float(elapsed) / Float(scrollDuration)
            overlayMaterial.diffuse.contentsTransform = SCNMatrix4MakeTranslation(0, -progress, 0)
        }
    )
    overlayNode.runAction(scrollAction)

    return scene
}

/// Generate a procedural vertical streak texture using Core Image.
func generateStreakTexture(size: CGSize) -> UIImage {
    let ciContext = CIContext()
    // 1. Generate noise
    let noiseFilter = CIFilter.randomGenerator()
    guard let noiseImage = noiseFilter.outputImage else {
        return UIImage()
    }
    // 2. Scale to create streak effect (narrow x, tall y)
    let scaleX = 0.001
    let scaleY = 2.0
    let transform = CGAffineTransform(scaleX: CGFloat(scaleX), y: CGFloat(scaleY))
    let scaledImage = noiseImage.transformed(by: transform)
    // 3. Crop to desired size
    let cropped = scaledImage.cropped(to: CGRect(origin: .zero, size: size))
    // 4. Increase contrast and reduce brightness for sharper streaks
    let controls = CIFilter.colorControls()
    controls.inputImage = cropped
    controls.contrast = 4.0
    controls.brightness = -1.05
    controls.saturation = 0.0
    guard let contrasted = controls.outputImage else {
        return UIImage()
    }
    // 5. Optional slight blur
    let blur = CIFilter.gaussianBlur()
    blur.inputImage = contrasted
    blur.radius = 1.0
    guard let blurred = blur.outputImage else {
        return UIImage()
    }
    // 6. Render to UIImage
    let finalCGImage = ciContext.createCGImage(blurred, from: CGRect(origin: .zero, size: size))!
    return UIImage(cgImage: finalCGImage)
}

#Preview {
    RainSceneView()
}
