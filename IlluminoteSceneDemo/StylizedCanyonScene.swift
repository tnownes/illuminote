import SwiftUI
//
//  StylizedCanyonScene.swift
//  IlluminoteSceneDemo
//
//  Created by Nownes, Tobias on 5/6/25.
//

import SceneKit
import UIKit
import QuartzCore  // Ensure this is at the top of the file


// Crossfade between two sky layers to simulate transition from sunset to night
func addCrossfadeSkyLayer(to scene: SCNScene, sunsetImage: String, nightImage: String, width: CGFloat, height: CGFloat, fadeDuration: TimeInterval) {
    let sunsetPlane = SCNPlane(width: width, height: height)
    let sunsetMaterial = SCNMaterial()
    sunsetMaterial.diffuse.contents = UIImage(named: sunsetImage)
    sunsetMaterial.isDoubleSided = true
    sunsetPlane.materials = [sunsetMaterial]

    // Debug: Check if sunset image loaded
    if sunsetMaterial.diffuse.contents == nil {
        print("⚠️ Sunset image not loaded.")
    } else {
        print("✅ Sunset image loaded.")
    }

    let nightPlane = SCNPlane(width: width, height: height)
    let nightMaterial = SCNMaterial()
    nightMaterial.diffuse.contents = UIImage(named: nightImage)
    nightMaterial.isDoubleSided = true
    nightMaterial.writesToDepthBuffer = false
    nightPlane.materials = [nightMaterial]

    // Debug: Check if night image loaded
    if nightMaterial.diffuse.contents == nil {
        print("⚠️ Night image not loaded.")
    } else {
        print("✅ Night image loaded.")
    }

    let sunsetNode = SCNNode(geometry: sunsetPlane)
    sunsetNode.position = SCNVector3(0, 0, -10)

    let nightNode = SCNNode(geometry: nightPlane)
    nightNode.position = SCNVector3(0, 0, -9.9)
    nightNode.opacity = 0.0

    scene.rootNode.addChildNode(sunsetNode)
    scene.rootNode.addChildNode(nightNode)

    let fadeIn = SCNAction.fadeOpacity(to: 1.0, duration: fadeDuration)
    let pauseOnNight = SCNAction.wait(duration: fadeDuration * 3)
    let fadeOut = SCNAction.fadeOpacity(to: 0.0, duration: fadeDuration)
    let loop = SCNAction.repeatForever(SCNAction.sequence([fadeIn, pauseOnNight, fadeOut]))
    nightNode.runAction(loop)
}

func createStylizedCanyonScene() -> SCNScene {
    let scene = SCNScene()

    // MARK: - Lighting
    let ambientLight = SCNLight()
    ambientLight.type = .ambient
    ambientLight.color = UIColor(white: 1.0, alpha: 1.0)
    let ambientNode = SCNNode()
    ambientNode.light = ambientLight
    scene.rootNode.addChildNode(ambientNode)

    // MARK: - Camera
    let cameraNode = SCNNode()
    cameraNode.camera = SCNCamera()
    cameraNode.camera?.fieldOfView = 60
    cameraNode.position = SCNVector3(0, 0, 10)
    scene.rootNode.addChildNode(cameraNode)

    // MARK: - Layer Helper
    func addLayer(imageName: String, position: SCNVector3, width: CGFloat, height: CGFloat, animateXOffset: Bool = false) {
        let plane = SCNPlane(width: width, height: height)
        let material = SCNMaterial()
        material.diffuse.contents = UIImage(named: imageName)
        material.isDoubleSided = true
        plane.materials = [material]

        let node = SCNNode(geometry: plane)
        node.position = position
        scene.rootNode.addChildNode(node)

        if animateXOffset {
            let moveRight = SCNAction.moveBy(x: 0.3, y: 0, z: 0, duration: 4.0)
            let moveLeft = SCNAction.moveBy(x: -0.3, y: 0, z: 0, duration: 4.0)
            let sequence = SCNAction.sequence([moveRight, moveLeft])
            let loop = SCNAction.repeatForever(sequence)
            node.runAction(loop)
        }
    }

    // MARK: - Stylized Layers
    addCrossfadeSkyLayer(to: scene, sunsetImage: "sunset_sky", nightImage: "night_sky", width: 20, height: 20, fadeDuration: 60)
    addLayer(imageName: "canyon_wall", position: SCNVector3(0, -0.5, -9), width: 20, height: 6, animateXOffset: false)
    addLayer(imageName: "distant_trees", position: SCNVector3(0, -1.0, -8), width: 18, height: 4, animateXOffset: false)
    addLayer(imageName: "foreground_rock", position: SCNVector3(0, -1.5, -7), width: 16, height: 3.5, animateXOffset: false)
    addLayer(imageName: "mist_layer", position: SCNVector3(0, -1.0, -6.5), width: 20, height: 5, animateXOffset: false)

    // MARK: - Moon Node
    let moonGeometry = SCNSphere(radius: 0.5)
    let moonMaterial = SCNMaterial()
    moonMaterial.diffuse.contents = UIColor.white
    moonMaterial.emission.contents = UIColor.white
    moonMaterial.lightingModel = .constant
    moonGeometry.materials = [moonMaterial]

    let moonNode = SCNNode(geometry: moonGeometry)
    moonNode.position = SCNVector3(5, 4, -9.8)
    moonNode.opacity = 0.0

    scene.rootNode.addChildNode(moonNode)

    // MARK: - Crescent Mask for Moon
    let maskGeometry = SCNSphere(radius: 0.5)
    let maskMaterial = SCNMaterial()
    maskMaterial.diffuse.contents = UIColor.black
    maskMaterial.lightingModel = .constant
    maskGeometry.materials = [maskMaterial]

    let maskNode = SCNNode(geometry: maskGeometry)
    maskNode.position = SCNVector3(5.2, 4, -9.7)  // Slightly offset to create crescent shape
    moonNode.addChildNode(maskNode)

    // MARK: - Moonlight Source
    let moonLight = SCNLight()
    moonLight.type = .omni
    moonLight.intensity = 300  // Soft glow
    moonLight.color = UIColor.white
    moonLight.attenuationStartDistance = 1
    moonLight.attenuationEndDistance = 20
    moonLight.attenuationFalloffExponent = 2

    let moonLightNode = SCNNode()
    moonLightNode.light = moonLight
    moonLightNode.position = SCNVector3(5, 4, -9.7)

    scene.rootNode.addChildNode(moonLightNode)

    // Animate the moon fading in (no motion), but delay the fade-in
    // For testing: set moon to fully visible immediately
    moonNode.opacity = 1.0

    // MARK: - Star Field Particle System
    let starField = SCNParticleSystem()
    starField.birthRate = 1
    starField.particleLifeSpan = 60
    starField.particleSize = 0.02
    starField.emitterShape = SCNSphere(radius: 8)
    starField.particleColor = UIColor.white
    starField.blendMode = .additive
    starField.particleVelocity = 0
    starField.particleImage = UIImage(named: "spark.png")
    starField.particleColorVariation = SCNVector4(0, 0, 0, 0.6)  // Only vary alpha
    starField.isLightingEnabled = false

    let starNode = SCNNode()
    starNode.position = SCNVector3(0, 2, -9)
    starNode.addParticleSystem(starField)
    scene.rootNode.addChildNode(starNode)

    return scene
}

// MARK: - SwiftUI Wrapper for SceneKit Scene

struct StylizedCanyonSceneView: View {
    var body: some View {
        SceneView(
            scene: createStylizedCanyonScene(),
            pointOfView: nil,
            options: [.allowsCameraControl],
            preferredFramesPerSecond: 60,
            antialiasingMode: .multisampling4X,
            delegate: nil,
            technique: nil
        )
        .ignoresSafeArea()
    }
}

#Preview {
    StylizedCanyonSceneView()
}
