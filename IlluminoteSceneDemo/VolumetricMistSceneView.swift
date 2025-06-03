import SwiftUI
import SceneKit

struct VolumetricMistSceneView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let scnView = SCNView()
        scnView.scene = createScene()
        scnView.allowsCameraControl = false
        scnView.autoenablesDefaultLighting = false
        scnView.backgroundColor = UIColor(red: 0.1, green: 0.12, blue: 0.18, alpha: 1)

        let hostingController = UIHostingController(rootView:
            ZStack {
                Color.clear
                ExamenOverlay()
            }
        )
        hostingController.view.backgroundColor = .clear

        let containerView = UIView()
        containerView.addSubview(scnView)
        containerView.addSubview(hostingController.view)

        scnView.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scnView.topAnchor.constraint(equalTo: containerView.topAnchor),
            scnView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            scnView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            scnView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: containerView.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
        ])

        return containerView
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    func createScene() -> SCNScene {
        
        // MARK: - Scene Setup
        let scene = SCNScene()
        // MARK: - Cloud Chunks
        scene.rootNode.addChildNode(makeCloudChunk(position: SCNVector3(2, 4, -4)))
        scene.rootNode.addChildNode(makeCloudChunk(position: SCNVector3(-1, 3, -2)))
        scene.rootNode.addChildNode(makeCloudChunk(position: SCNVector3(0, 2, -3), emitterShapeType: "cylinder"))

        // MARK: - Background Gradient (Soft Sky)
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = CGRect(x: 0, y: 0, width: 1, height: 256)
        gradientLayer.colors = [
            UIColor(red: 0.8, green: 0.9, blue: 1.0, alpha: 1.0).cgColor,  // Top (lighter)
            UIColor(red: 0.5, green: 0.7, blue: 0.9, alpha: 1.0).cgColor   // Bottom (darker)
        ]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)

        UIGraphicsBeginImageContextWithOptions(gradientLayer.frame.size, false, 0)
        gradientLayer.render(in: UIGraphicsGetCurrentContext()!)
        let gradientImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        scene.background.contents = gradientImage

        // MARK: - Camera Setup
        // Camera setup
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(0, 0, 10)
        scene.rootNode.addChildNode(cameraNode)

        // MARK: - Floor (Light Contrast Surface)
        // Add a subtle floor for light contrast
        let floor = SCNFloor()
        floor.reflectivity = 0.0
        let floorMaterial = SCNMaterial()
        floorMaterial.diffuse.contents = UIColor(white: 1.0, alpha: 0.05)  // translucent foggy glow
        floor.firstMaterial = floorMaterial
        let floorNode = SCNNode(geometry: floor)
        scene.rootNode.addChildNode(floorNode)

        // MARK: - Directional Light
        // Directional light for shafts
        let lightNode = SCNNode()
        let light = SCNLight()
        light.type = .directional
        light.intensity = 1000
        light.castsShadow = true
        light.shadowMode = .deferred
        light.shadowColor = UIColor.black.withAlphaComponent(0.6)
        lightNode.light = light
        lightNode.eulerAngles = SCNVector3(-Float.pi/3, 0, 0)
        scene.rootNode.addChildNode(lightNode)

        // MARK: - Light Shaft (Spotlight + Visual Beam)
        // Light shaft simulation using a spotlight and translucent cone
        let shaftLight = SCNLight()
        shaftLight.type = .spot
        shaftLight.spotInnerAngle = 10
        shaftLight.spotOuterAngle = 45
        shaftLight.intensity = 500
        shaftLight.castsShadow = false
        shaftLight.color = UIColor.white.withAlphaComponent(0.2)

        let shaftLightNode = SCNNode()
        shaftLightNode.light = shaftLight
        shaftLightNode.position = SCNVector3(0, 10, 10)
        shaftLightNode.eulerAngles = SCNVector3(-Float.pi / 3, 0, 0)

        // Add a semi-transparent cone mesh to visualize the beam
        let shaftGeometry = SCNCone(topRadius: 0, bottomRadius: 3, height: 10)
        shaftGeometry.firstMaterial?.diffuse.contents = UIColor.white.withAlphaComponent(0.1)
        shaftGeometry.firstMaterial?.isDoubleSided = true
        shaftGeometry.firstMaterial?.lightingModel = .constant
        shaftGeometry.firstMaterial?.writesToDepthBuffer = false
        let shaftVisualNode = SCNNode(geometry: shaftGeometry)
        shaftVisualNode.position = SCNVector3(0, 5, 0)
        shaftLightNode.addChildNode(shaftVisualNode)

        scene.rootNode.addChildNode(shaftLightNode)

        // MARK: - Primary Mist Particle System
        // Volumetric mist particles (programmatic)
        let mist = SCNParticleSystem()
        mist.birthRate = 5
        mist.particleLifeSpan = 30
        mist.particleVelocity = 0.1
        mist.particleVelocityVariation = 0.05
        mist.particleSize = 0.05
        mist.particleColor = UIColor(red: 0.8, green: 0.85, blue: 0.9, alpha: 0.15)
        mist.blendMode = .additive
        mist.emitterShape = SCNBox(width: 10, height: 8, length: 10, chamferRadius: 0)
        mist.isAffectedByGravity = false
        mist.isLightingEnabled = true
        mist.particleImage = UIImage(named: "spark_blurred.png")
        mist.particleAngularVelocity = 0.2
        mist.particleAngularVelocityVariation = 0.5
        mist.emissionDuration = 0  // Continuous emission
        mist.acceleration = SCNVector3(0, -0.02, 0)  // Subtle downward drift

        let mistNode = SCNNode()
        mistNode.addParticleSystem(mist)
        scene.rootNode.addChildNode(mistNode)

        // MARK: - Secondary Mist Layer (Depth)
        // Second mist layer for depth
        let mist2 = SCNParticleSystem()
        mist2.birthRate = 3
        mist2.particleLifeSpan = 40
        mist2.particleVelocity = 0.05
        mist2.particleVelocityVariation = 0.02
        mist2.particleSize = 0.08
        mist2.particleColor = UIColor(red: 0.75, green: 0.8, blue: 0.85, alpha: 0.1)
        mist2.blendMode = .additive
        mist2.emitterShape = SCNBox(width: 12, height: 10, length: 12, chamferRadius: 0)
        mist2.isAffectedByGravity = false
        mist2.isLightingEnabled = true
        mist2.particleImage = UIImage(named: "spark_blurred.png")
        mist2.particleAngularVelocity = 0.1
        mist2.particleAngularVelocityVariation = 0.4
        mist2.emissionDuration = 0
        mist2.acceleration = SCNVector3(0, -0.015, 0)

        let mistNode2 = SCNNode()
        mistNode2.addParticleSystem(mist2)
        scene.rootNode.addChildNode(mistNode2)

        // MARK: - Return Final Scene
        return scene
    }
}

// MARK: - Examen Prompt Overlay (SwiftUI)
struct ExamenOverlay: View {
    var body: some View {
        VStack {
            Spacer()
            Text("Reflect on a moment of peace today")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding()
                .background(Color.black.opacity(0.4))
                .cornerRadius(12)
            Spacer()
        }
        .padding()
    }
}
