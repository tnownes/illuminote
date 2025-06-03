import SwiftUI
import SceneKit

struct MystSceneView: View {
    var body: some View {
        SceneView(
            scene: SCNScene(),
            options: [.allowsCameraControl]
        )
        .ignoresSafeArea()
    }
}
