//
//  CloudChunk.swift
//  IlluminoteSceneDemo
//
//  Created by Nownes, Tobias on 5/6/25.
//

import SceneKit
import UIKit

func makeCloudChunk(position: SCNVector3, size: CGFloat = 1.5, emitterShapeType: String = "sphere") -> SCNNode {
    let cloud = SCNParticleSystem()
    cloud.birthRate = 50
    cloud.particleLifeSpan = 2
    cloud.particleVelocity = 0.01
    cloud.particleVelocityVariation = 2.1
    cloud.particleSize = 0.15
    cloud.particleColor = UIColor(white: 1.0, alpha: 0.25)
    cloud.blendMode = .alpha
    cloud.isLightingEnabled = false
    cloud.particleImage = UIImage(named: "spark_blurred.png")
    cloud.acceleration = SCNVector3(0.000, 0.001, 0.000)
    cloud.emissionDuration = 1.0
    cloud.emissionDurationVariation = 0.2
    cloud.loops = true

    switch emitterShapeType.lowercased() {
    case "cylinder":
        cloud.emitterShape = SCNCylinder(radius: size * 1.5, height: size * 0.4)
    case "plane":
        cloud.emitterShape = SCNPlane(width: size * 2, height: size)
    default:
        cloud.emitterShape = SCNSphere(radius: size)
    }

    let node = SCNNode()
    node.position = position
    node.addParticleSystem(cloud)
    return node
}
