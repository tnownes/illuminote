import SwiftUI
import SceneKit

struct TuscanySceneView: View {
    var body: some View {
        SceneView(
            scene: SCNScene(),
            options: [.allowsCameraControl]
        )
        .ignoresSafeArea()
    }
}
