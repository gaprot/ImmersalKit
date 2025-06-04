import ImmersalKit
import RealityKit
import SwiftUI

struct ControlButtonsSection: View {
  let immersalKit: ImmersalKit
  let isImmersiveActive: Bool
  let selectedMapIds: Set<Int>
  let onLoadMaps: () -> Void
  let onStartLocalizing: () -> Void
  let onStopLocalizing: () -> Void
  let onReset: () -> Void
  let isMapLoaded: Bool

  var body: some View {
    VStack(spacing: 15) {
      // Map loading button
      Button("Load Selected Maps") {
        onLoadMaps()
      }
      .buttonStyle(.borderedProminent)
      .disabled(selectedMapIds.isEmpty || immersalKit.isLocalizing)
      .padding(.top)

      // Localize button
      if isImmersiveActive {
        Button(immersalKit.isLocalizing ? "Stop Localization" : "Start Localization") {
          immersalKit.isLocalizing ? onStopLocalizing() : onStartLocalizing()
        }
        .buttonStyle(.borderedProminent)
        .tint(immersalKit.isLocalizing ? .red : .green)
        .disabled(!isMapLoaded)
      }

      // Reset button
      Button("Reset") {
        onReset()
      }
      .buttonStyle(.bordered)
      .foregroundColor(.red)
      .padding(.top, 5)
    }
    .padding()
    .background(Color.gray.opacity(0.1))
    .cornerRadius(10)
    .padding(.horizontal)
  }
}
