import ImmersalKit
import RealityKit
import SwiftUI

struct MapViewModel: Identifiable {
  let id: Int
  let name: String
  let details: String
  let status: String?

  static func from(job: Job) -> MapViewModel {
    return MapViewModel(
      id: job.id,
      name: job.name,
      details: "\(job.id) • \(job.size) images",
      status: job.status
    )
  }

  static func from(mapId: Int, mapEntry: MapEntry) -> MapViewModel {
    return MapViewModel(
      id: mapId,
      name: "\(mapEntry.mapId)",
      details: "ID: \(mapEntry.mapId)",
      status: nil
    )
  }
}

struct MapSelectionSection: View {
  let immersalKit: ImmersalKit
  let isLoadingMaps: Bool
  let availableMaps: [Job]
  @Binding var selectedMapIds: Set<Int>
  let onRefresh: () -> Void
  let onSelectMap: (MapId) -> Void

  // Convert to display map data
  private var mapViewModels: [MapViewModel] {
    if immersalKit.localizerType == .restApi && !availableMaps.isEmpty {
      // Convert data via REST API
      return availableMaps.map { MapViewModel.from(job: $0) }
    } else {
      // Convert predefined map data
      return immersalKit.mapManager.mapEntries.map { (mapId, entry) in
        MapViewModel.from(mapId: mapId, mapEntry: entry)
      }
    }
  }

  var body: some View {
    VStack(spacing: 10) {
      HStack {
        Label {
          Text("Maps")
            .font(.headline)
        } icon: {
          Image(systemName: "map")
            .imageScale(.medium)
        }

        Spacer()

        Button(action: onRefresh) {
          Image(systemName: "arrow.clockwise")
            .imageScale(.medium)
        }
        .disabled(immersalKit.isLocalizing)
      }

      if isLoadingMaps {
        ProgressView("Loading map list...")
          .padding()
      } else {
        MapListView(
          maps: mapViewModels,
          selectedMapIds: selectedMapIds,
          isLocalizing: immersalKit.isLocalizing,
          onSelectMap: onSelectMap
        )
      }
    }
    .padding()
    .background(Color.gray.opacity(0.1))
    .cornerRadius(10)
    .padding(.horizontal)
  }

  struct MapListView: View {
    let maps: [MapViewModel]
    let selectedMapIds: Set<Int>
    let isLocalizing: Bool
    let onSelectMap: (MapId) -> Void

    var body: some View {
      ScrollView {
        ForEach(maps) { map in
          MapButton(
            mapId: map.id,
            name: map.name,
            details: map.details,
            status: map.status,
            isSelected: selectedMapIds.contains(map.id),
            isDisabled: isLocalizing,
            onSelect: {
              onSelectMap(map.id)
            }
          )
        }
      }
      .frame(height: 250)
    }
  }

  /// Map button
  struct MapButton: View {
    let mapId: Int
    let name: String
    let details: String
    let status: String?
    let isSelected: Bool
    let isDisabled: Bool
    let onSelect: () -> Void

    var body: some View {
      Button(action: onSelect) {
        HStack {
          // Map status icon (display only when status is available)
          if let status = status {
            Image(systemName: statusIconName(for: status))
              .foregroundColor(statusColor(for: status))
          }

          // Map information
          VStack(alignment: .leading, spacing: 2) {
            Text(name)
              .fontWeight(.medium)

            Text(details)
              .font(.caption)
              .foregroundColor(.secondary)
          }

          Spacer()

          // Selection state
          if isSelected {
            Image(systemName: "checkmark.circle.fill")
              .foregroundColor(.blue)
              .symbolEffect(.bounce, options: .repeating)
          }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(8)
      }
      .buttonStyle(.plain)
      .disabled(isDisabled)
      .opacity(isDisabled ? 0.6 : 1.0)
    }

    /// Status icon name
    private func statusIconName(for status: String) -> String {
      switch status {
      case "done":
        return "checkmark.circle"
      case "failed":
        return "xmark.circle"
      case "processing":
        return "gear"
      case "pending":
        return "clock"
      default:
        return "questionmark.circle"
      }
    }

    /// Status color
    private func statusColor(for status: String) -> Color {
      switch status {
      case "done":
        return .green
      case "failed":
        return .red
      case "processing":
        return .orange
      case "pending":
        return .yellow
      default:
        return .gray
      }
    }
  }
}
