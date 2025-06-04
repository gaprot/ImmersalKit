//
//  DemoApp.swift
//  Demo
//
//  Created by ryudai.kimura on 2025/05/27.
//

import ARKit
import ImmersalKit
import RealityKit
import RealityKitContent
import SwiftUI

@main
struct DemoApp: App {

  @State private var isImmersiveActive = false
  @Environment(\.openImmersiveSpace) var openImmersiveSpace
  @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace

  private let immersalKit = ImmersalKit(
    localizerType: .posePlugin,
    arSessionManager: ARSessionManager()
  )

  init() {
    RealityKitContent.ImmersalMapComponent.registerComponent()
  }

  var body: some SwiftUI.Scene {
    WindowGroup {
      ImmersalControlPanel(
        immersalKit: immersalKit,
        isImmersiveActive: $isImmersiveActive
      )
      .frame(minWidth: 600, minHeight: 900)
      .onAppear {
        Task {
          switch await openImmersiveSpace(id: "ImmersalSpace") {
          case .opened:
            isImmersiveActive = true
          case .userCancelled:
            isImmersiveActive = false
          case .error:
            isImmersiveActive = false
          default:
            isImmersiveActive = false
          }
          print("isImmersiveActive: \(isImmersiveActive)")
        }
      }
    }
    .defaultSize(width: 600, height: 900)

    ImmersiveSpace(id: "ImmersalSpace") {
      ImmersalSpaceView(immersalKit: immersalKit)
    }
    .immersionStyle(selection: .constant(.mixed), in: .mixed)
  }
}
