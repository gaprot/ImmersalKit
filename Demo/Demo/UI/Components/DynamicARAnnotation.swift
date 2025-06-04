import RealityKit
import SwiftUI

struct DynamicARAnnotation: View {
  let id: String
  let title: String
  let createdAt: Date
  let onDelete: () -> Void

  @State private var isHovered = false

  var body: some View {
    VStack(spacing: 8) {
      HStack {
        Image(systemName: "mappin.circle.fill")
          .foregroundColor(.blue)
          .font(.title3)

        Text(title)
          .font(.headline)
          .lineLimit(1)

        Spacer()

        Button(action: onDelete) {
          Image(systemName: "xmark.circle.fill")
            .foregroundColor(.red.opacity(0.8))
        }
        .buttonStyle(.plain)
      }

      Text("Created: \(createdAt, style: .time)")
        .font(.caption2)
        .foregroundColor(.secondary)

      if isHovered {
        Text("ID: \(id)")
          .font(.caption2)
          .foregroundColor(.secondary)
      }
    }
    .padding(12)
    .frame(minWidth: 180, maxWidth: 250)
    .background(isHovered ? Color.blue.opacity(0.1) : Color.clear)
    .background(.regularMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .shadow(radius: isHovered ? 12 : 6)
    .scaleEffect(isHovered ? 1.05 : 1.0)
    .onHover { hovering in
      withAnimation(.easeInOut(duration: 0.2)) {
        isHovered = hovering
      }
    }
    .allowsHitTesting(true)  // Ensure UI can receive touches
  }
}

struct ARCoordinateDisplay: View {
  let position: SIMD3<Float>
  let rotation: simd_quatf

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Label("Position", systemImage: "location")
        .font(.caption.bold())

      HStack(spacing: 12) {
        CoordinateLabel(axis: "X", value: position.x, color: .red)
        CoordinateLabel(axis: "Y", value: position.y, color: .green)
        CoordinateLabel(axis: "Z", value: position.z, color: .blue)
      }

      let eulerAngles = rotation.eulerAngles
      Label("Rotation", systemImage: "rotate.3d")
        .font(.caption.bold())
        .padding(.top, 4)

      HStack(spacing: 12) {
        CoordinateLabel(axis: "P", value: eulerAngles.x * 180 / .pi, color: .red)
        CoordinateLabel(axis: "Y", value: eulerAngles.y * 180 / .pi, color: .green)
        CoordinateLabel(axis: "R", value: eulerAngles.z * 180 / .pi, color: .blue)
      }
    }
    .padding()
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

struct CoordinateLabel: View {
  let axis: String
  let value: Float
  let color: Color

  var body: some View {
    VStack(spacing: 2) {
      Text(axis)
        .font(.caption2)
        .foregroundColor(color)
      Text("\(value, specifier: "%.2f")")
        .font(.caption.monospaced())
    }
  }
}

extension simd_quatf {
  var eulerAngles: SIMD3<Float> {
    let qw = self.real
    let qx = self.imag.x
    let qy = self.imag.y
    let qz = self.imag.z

    let pitch = atan2(2 * (qw * qx + qy * qz), 1 - 2 * (qx * qx + qy * qy))
    let yaw = asin(max(-1, min(1, 2 * (qw * qy - qz * qx))))
    let roll = atan2(2 * (qw * qz + qx * qy), 1 - 2 * (qy * qy + qz * qz))

    return SIMD3<Float>(pitch, yaw, roll)
  }
}
