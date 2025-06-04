import ImmersalKit
import RealityKit
import SwiftUI

struct StatusMessageView: View {
  let message: String

  var body: some View {
    Text(message)
      .padding()
      .background(Color.black.opacity(0.7))
      .foregroundColor(.white)
      .cornerRadius(8)
  }
}
