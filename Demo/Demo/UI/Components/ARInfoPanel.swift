import SwiftUI

struct ARInfoPanel: View {
  let mapId: Int
  let position: SIMD3<Float>
  let confidence: Float?
  let isLocalized: Bool

  @State private var isExpanded = false

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Image(systemName: isLocalized ? "location.fill" : "location.slash")
          .foregroundColor(isLocalized ? .green : .orange)

        Text("Map \(mapId)")
          .font(.headline)
          .foregroundColor(.primary)

        Spacer()

        Button(action: { withAnimation { isExpanded.toggle() } }) {
          Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            .foregroundColor(.secondary)
        }
      }

      if isExpanded {
        VStack(alignment: .leading, spacing: 4) {
          HStack {
            Text("Status:")
              .font(.caption)
              .foregroundColor(.secondary)
            Text(isLocalized ? "Localized" : "Not Localized")
              .font(.caption)
              .foregroundColor(isLocalized ? .green : .orange)
          }

          if let confidence = confidence {
            HStack {
              Text("Confidence:")
                .font(.caption)
                .foregroundColor(.secondary)
              Text("\(confidence, specifier: "%.1f")%")
                .font(.caption)
                .foregroundColor(.primary)
            }
          }

          HStack {
            Text("Position:")
              .font(.caption)
              .foregroundColor(.secondary)
            Text(
              "(\(position.x, specifier: "%.2f"), \(position.y, specifier: "%.2f"), \(position.z, specifier: "%.2f"))"
            )
            .font(.caption2)
            .foregroundColor(.primary)
          }
        }
        .padding(.top, 4)
      }
    }
    .padding(12)
    .frame(minWidth: 200, maxWidth: 300)
    .background(.regularMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .shadow(radius: 8)
    .allowsHitTesting(true)  // Ensure UI can receive touches
  }
}

struct ARInteractionPanel: View {
  let title: String
  let description: String
  @Binding var isActive: Bool
  let onTap: () -> Void

  var body: some View {
    VStack(spacing: 12) {
      Text(title)
        .font(.headline)
        .multilineTextAlignment(.center)

      Text(description)
        .font(.caption)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)

      Toggle("Active", isOn: $isActive)
        .toggleStyle(.switch)
        .labelsHidden()

      Button(action: onTap) {
        Label("Interact", systemImage: "hand.tap.fill")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.small)
    }
    .padding()
    .frame(width: 220)
    .background(.regularMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .shadow(radius: 12)
  }
}

struct ARLabelView: View {
  let text: String
  let icon: String
  let color: Color

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: icon)
        .font(.system(size: 14))
        .foregroundColor(color)

      Text(text)
        .font(.system(size: 14, weight: .medium))
        .foregroundColor(.primary)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .background(.ultraThinMaterial)
    .clipShape(Capsule())
    .shadow(radius: 4)
  }
}
