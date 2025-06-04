import ImmersalKit
import RealityKit
import SwiftUI

struct LocalizerStatusSection: View {
  let immersalKit: ImmersalKit

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Localizer Status: \(immersalKit.lastResult.debugDescription)")
        .fontWeight(.medium)

      if let confidence = immersalKit.lastResult?.normalizedConfidence() {
        if confidence > 0.0 {
          //Text("Localization attempts: \(immersalKit.activeLocalizer.localizationCount)")
          //Text("Localization successes: \(immersalKit.activeLocalizer.successCount)")

          if let position = immersalKit.lastResult?.position {
            Text(
              "Last Position: X: \(String(format: "%.2f", position.x)) Y: \(String(format: "%.2f", position.y)) Z: \(String(format: "%.2f", position.z))"
            )
          }

          Text("Confidence: \(confidence)")
        }
      }
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.gray.opacity(0.1))
    .cornerRadius(10)
    .padding(.horizontal)

  }
}
