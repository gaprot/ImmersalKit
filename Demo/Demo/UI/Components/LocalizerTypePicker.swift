import ImmersalKit
import RealityKit
import SwiftUI

struct LocalizerTypePicker: View {
  let immersalKit: ImmersalKit

  var body: some View {
    Picker(
      "Localizer Type",
      selection: Binding(
        get: { immersalKit.localizerType },
        set: { newValue in
          // Reject changes during localization
          if !immersalKit.isLocalizing {
            immersalKit.localizerType = newValue
          }
        }
      )
    ) {
      Text("On Device").tag(LocalizerType.posePlugin)
      Text("REST API").tag(LocalizerType.restApi)
    }
    .pickerStyle(SegmentedPickerStyle())
    .disabled(immersalKit.isLocalizing)
    .opacity(immersalKit.isLocalizing ? 0.6 : 1.0)
    .padding(.horizontal)
  }
}
