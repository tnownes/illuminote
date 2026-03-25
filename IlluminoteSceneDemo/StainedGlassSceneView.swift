import SwiftUI
import SceneKit

struct StainedGlassSceneView: View {
    // MARK: - Scene objects (built once)
    private let scene = SCNScene()
    private let camera = SCNCamera()
    private let cameraNode = SCNNode()
    private let plane: SCNPlane
    private let planeNode = SCNNode()
    private let material = SCNMaterial()

    // Keep a reference to the source image for aspect math
    private let bgImage: UIImage?

    // MARK: - Init builds the scene once
    init() {
        // Load image
        let img = UIImage(named: "stained-glass-reference-design2")
        scene.background.contents = img ?? UIColor.systemBackground
        self.bgImage = img

        // Fallback aspect if image is missing
        let imgAspect: CGFloat = {
            guard let img else { return 9.0/16.0 }
            return img.size.width / img.size.height
        }()

        // Base plane dimensions in world units (height-focused)
        let baseHeight: CGFloat = 6.0
        let baseWidth: CGFloat = baseHeight * imgAspect

        // Configure plane + material
        let plane = SCNPlane(width: baseWidth, height: baseHeight)
        self.plane = plane
        material.diffuse.contents = UIColor.clear
        material.emission.contents = nil
        material.emission.intensity = 0.0
        material.lightingModel = .constant
        material.isDoubleSided = true
        plane.materials = [material]

        // Hide the plane (we only want the background image filling the scene)
        planeNode.isHidden = true

        planeNode.geometry = plane
        planeNode.position = SCNVector3(0, 0, -Float(baseHeight / 2))

        // Configure camera with HDR/bloom for gentle glow
        camera.wantsHDR = true
        camera.bloomIntensity = 0.8
        camera.bloomBlurRadius = 8.0
        camera.exposureOffset = 0.15
        camera.minimumExposure = -1.0
        camera.maximumExposure = 1.0

        // Use orthographic projection so we can size precisely to the view
        camera.usesOrthographicProjection = true
        camera.orthographicScale = Double(baseHeight) // will be updated per layout

        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, 0) // looks down -Z by default

        // Assemble scene graph
        scene.rootNode.addChildNode(cameraNode)
        scene.rootNode.addChildNode(planeNode)

        // Emissive pulse (smooth ease in/out)
        let minIntensity: CGFloat = 0.8
        let maxIntensity: CGFloat = 2.5
        let upDuration: TimeInterval = 10.0
        let downDuration: TimeInterval = 16.0
        let delta = maxIntensity - minIntensity

        let mat = self.material

        let pulseUp = SCNAction.customAction(duration: upDuration) { _, elapsed in
            let p = CGFloat(elapsed) / CGFloat(upDuration)
            let eased = 0.5 - 0.5 * cos(.pi * p)
            mat.emission.intensity = minIntensity + delta * eased
        }
        let pulseDown = SCNAction.customAction(duration: downDuration) { _, elapsed in
            let p = CGFloat(elapsed) / CGFloat(downDuration)
            let eased = 0.5 - 0.5 * cos(.pi * (1.0 - p))
            mat.emission.intensity = maxIntensity - delta * eased
        }
        let sequence = SCNAction.sequence([pulseUp, pulseDown])
        planeNode.runAction(.repeatForever(sequence))
    }

    var body: some View {
        GeometryReader { proxy in
            SceneView(
                scene: scene,
                options: []
            )
            .ignoresSafeArea()
            .onAppear { updateLayout(for: proxy.size) }
            .onChange(of: proxy.size, initial: false) { _, newSize in updateLayout(for: newSize) }
        }
        .overlay {
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.2)
                .ignoresSafeArea()
        }
    }

    // MARK: - Layout helper
    /// Update camera scale so the plane aspect-fills the view without letterboxing.
    private func updateLayout(for size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }

        // Base plane dimensions (already set in init)
        let baseHeight: CGFloat = plane.height
        let baseWidth: CGFloat = plane.width

        // View aspect
        let viewAspect = size.width / size.height

        // For orthographic cameras, orthographicScale is the vertical size of the view in world units.
        // To achieve aspect-FILL: choose a scale that ensures the plane fully covers the view in both axes.
        // If the plane is relatively wider than the view (imgAspect > viewAspect), height is limiting → use baseHeight.
        // If the plane is relatively taller (imgAspect < viewAspect), width is limiting → scale by width / viewAspect.
        let scale = max(baseHeight, baseWidth / viewAspect)

        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.25
        camera.orthographicScale = Double(scale)
        SCNTransaction.commit()
    }
}

#Preview {
    StainedGlassSceneView()
}
