import Foundation
import RealityKit
import SwiftUI

/// Map loading source types
public enum MapSource {
  /// Load from main bundle resources
  case mainBundle
  // Future extensions:
  // case customBundle(Bundle)
  // case url(URL)
  // case data(Data)
}

public enum MapManagementEvent {
  case registered(MapId)
  case loaded(MapId)
  case unloaded(MapId)
  case error(ImmersalKitError)
}

@Observable
public final class MapManager {
  public private(set) var loadedMaps: [MapId: MapHandle] = [:]
  public private(set) var mapEntries: [MapId: MapEntry] = [:]

  private var eventContinuation: AsyncStream<MapManagementEvent>.Continuation?
  private let errorReporter: ErrorReporting

  public init(errorReporter: ErrorReporting = DefaultErrorReporter()) {
    self.errorReporter = errorReporter
  }

  public func mapEventStream() -> AsyncStream<MapManagementEvent> {
    return AsyncStream<MapManagementEvent> { continuation in
      self.eventContinuation = continuation
    }
  }

  /// Registers a map
  /// - Parameters:
  ///   - mapEntity: Map entity
  ///   - mapId: Map ID
  /// - Returns: Registration result
  public func registerMap(mapEntity: Entity, mapId: MapId) -> Result<Void, ImmersalKitError> {
    if mapEntries.keys.contains(mapId) {
      let error = ImmersalKitError.mapManagement(.mapAlreadyLoaded(mapId))
      errorReporter.reportError(error, context: ErrorContext(additionalInfo: ["mapId": mapId]))
      return .failure(error)
    }

    guard !mapEntity.name.isEmpty else {
      let error = ImmersalKitError.mapManagement(.invalidMapData(mapId))
      errorReporter.reportError(
        error,
        context: ErrorContext(additionalInfo: ["mapId": mapId, "reason": "Empty entity name"]))
      return .failure(error)
    }

    let entry = MapEntry(mapId: mapId, relation: MapToSpaceRelation(), sceneParent: mapEntity)
    mapEntries[mapId] = entry
    eventContinuation?.yield(.registered(mapId))

    return .success(())
  }

  /// Loads a map
  /// - Parameters:
  ///   - mapId: Map ID
  ///   - source: Map loading source (default: .mainBundle)
  /// - Returns: Load result
  @discardableResult
  public func loadMap(mapId: MapId, source: MapSource = .mainBundle) -> Result<
    Void, ImmersalKitError
  > {

    if loadedMaps.keys.contains(mapId) {
      return .success(())
    }

    guard let map = mapEntries[mapId] else {
      let error = ImmersalKitError.mapManagement(.mapNotFound(mapId))
      errorReporter.reportError(error, context: ErrorContext(additionalInfo: ["mapId": mapId]))
      return .failure(error)
    }

    guard map.sceneParent != nil else {
      let error = ImmersalKitError.mapManagement(.invalidMapData(mapId))
      errorReporter.reportError(
        error, context: ErrorContext(additionalInfo: ["mapId": mapId, "reason": "No scene parent"]))
      return .failure(error)
    }

    let loadResult = Self.loadMapFromSource(mapId: mapId, source: source)

    switch loadResult {
    case .success(let handle):
      self.loadedMaps[mapId] = handle
      eventContinuation?.yield(.loaded(mapId))
      return .success(())

    case .failure(let error):
      errorReporter.reportError(error, context: ErrorContext(additionalInfo: ["mapId": mapId]))
      eventContinuation?.yield(.error(error))
      return .failure(error)
    }
  }

  /// Unloads a map
  /// - Parameter mapId: Map ID
  /// - Returns: Unload result
  @discardableResult
  public func unloadMap(mapId: MapId) -> Result<Void, ImmersalKitError> {

    guard loadedMaps.keys.contains(mapId) else {
      let error = ImmersalKitError.mapManagement(.mapNotFound(mapId))
      errorReporter.reportError(
        error, context: ErrorContext(additionalInfo: ["mapId": mapId, "reason": "Map not loaded"]))
      return .failure(error)
    }

    let result = Core.freeMap(mapId: mapId)
    if result > 0 {
      loadedMaps.removeValue(forKey: mapId)
      eventContinuation?.yield(.unloaded(mapId))
      return .success(())
    } else {
      let error = ImmersalKitError.mapManagement(
        .mapUnloadFailed(mapId, "Core.freeMap returned \(result)"))
      errorReporter.reportError(
        error, context: ErrorContext(additionalInfo: ["mapId": mapId, "result": result]))
      eventContinuation?.yield(.error(error))
      return .failure(error)
    }
  }

  /// Resets all maps
  /// - Returns: Reset result
  public func resetAllMaps() -> Result<Void, ImmersalKitError> {
    var errors: [ImmersalKitError] = []

    for mapId in Array(loadedMaps.keys) {
      if case .failure(let error) = unloadMap(mapId: mapId) {
        errors.append(error)
      }
    }

    mapEntries.removeAll()

    if errors.isEmpty {
      return .success(())
    } else {
      let combinedError = ImmersalKitError.mapManagement(
        .mapUnloadFailed(-1, "Multiple unload failures: \(errors.count)"))
      errorReporter.reportError(
        combinedError, context: ErrorContext(additionalInfo: ["error_count": errors.count]))
      return .failure(combinedError)
    }
  }

  /// Sets map relationship
  /// - Parameters:
  ///   - mapId: Map ID
  ///   - position: Position
  ///   - rotation: Rotation
  ///   - scale: Scale (default is (1,1,1))
  /// - Returns: Setting result
  @MainActor
  public func setMapRelation(
    mapId: Int,
    position: simd_float3,
    rotation: simd_quatf,
    scale: simd_float3 = simd_float3(1, 1, 1)
  ) -> Result<Void, ImmersalKitError> {
    guard var entry = mapEntries[mapId] else {
      let error = ImmersalKitError.mapManagement(.mapNotFound(mapId))
      errorReporter.reportError(error, context: ErrorContext(additionalInfo: ["mapId": mapId]))
      return .failure(error)
    }

    guard position.x.isFinite && position.y.isFinite && position.z.isFinite else {
      let error = ImmersalKitError.configuration(.invalidParameter("Invalid position values"))
      errorReporter.reportError(
        error,
        context: ErrorContext(additionalInfo: ["position": [position.x, position.y, position.z]]))
      return .failure(error)
    }

    guard simd_length(rotation) > 0.1 else {
      let error = ImmersalKitError.configuration(.invalidParameter("Invalid rotation quaternion"))
      errorReporter.reportError(
        error, context: ErrorContext(additionalInfo: ["rotation_length": simd_length(rotation)]))
      return .failure(error)
    }

    guard scale.x > 0 && scale.y > 0 && scale.z > 0 else {
      let error = ImmersalKitError.configuration(.invalidParameter("Invalid scale values"))
      errorReporter.reportError(
        error, context: ErrorContext(additionalInfo: ["scale": [scale.x, scale.y, scale.z]]))
      return .failure(error)
    }

    entry.relation = MapToSpaceRelation(
      position: position,
      rotation: rotation,
      scale: scale
    )

    mapEntries[mapId] = entry

    if let entity = entry.sceneParent {
      entry.relation.applyToEntity(entity)
    }

    return .success(())
  }

  /// Applies all map relationships
  /// - Returns: Application result
  @MainActor
  public func applyAllMapRelations() -> Result<Void, ImmersalKitError> {
    var successCount = 0
    var errorCount = 0

    for (mapId, entry) in mapEntries {
      if let entity = entry.sceneParent {
        entry.relation.applyToEntity(entity)
        successCount += 1
      } else {
        errorCount += 1
        let error = ImmersalKitError.mapManagement(.invalidMapData(mapId))
        errorReporter.reportError(
          error,
          context: ErrorContext(additionalInfo: ["mapId": mapId, "reason": "No scene parent"]))
      }
    }

    if errorCount == 0 {
      return .success(())
    } else {
      let error = ImmersalKitError.configuration(
        .invalidParameter("Failed to apply \(errorCount) map relations"))
      return .failure(error)
    }
  }

  /// Internal implementation for loading map from specified source
  /// - Parameters:
  ///   - mapId: Map ID
  ///   - source: Map loading source
  /// - Returns: Map handle result
  public static func loadMapFromSource(mapId: MapId, source: MapSource) -> Result<
    MapHandle, ImmersalKitError
  > {
    switch source {
    case .mainBundle:
      return loadMapFromBundle(mapId: mapId)
    }
  }

  /// Internal implementation for loading map from bundle
  /// - Parameters:
  ///   - mapId: Map ID
  /// - Returns: Map handle result
  private static func loadMapFromBundle(mapId: MapId) -> Result<MapHandle, ImmersalKitError> {
    guard let url = findResourceURL(withId: mapId) else {
      return .failure(.mapManagement(.mapNotFound(mapId)))
    }

    do {
      let data = try Data(contentsOf: url)

      guard !data.isEmpty else {
        return .failure(.mapManagement(.invalidMapData(mapId)))
      }

      let ptr = UnsafeMutablePointer<Int8>.allocate(capacity: data.count)
      defer { ptr.deallocate() }

      let bytes = UnsafeMutableBufferPointer(start: ptr, count: data.count)
      let result = data.copyBytes(to: bytes)

      let handle = Core.loadMap(mapId: mapId, buffer: bytes.baseAddress!)

      if handle >= 0 {
        return .success(handle)
      } else {
        return .failure(.mapManagement(.mapLoadFailed(mapId, "Invalid map handle: \(handle)")))
      }
    } catch {
      return .failure(
        .mapManagement(.mapLoadFailed(mapId, "File read error: \(error.localizedDescription)")))
    }
  }

  static func findResourceURL(withId id: Int) -> URL? {
    guard let resourcePath = Bundle.main.resourcePath else { return nil }

    do {
      let files = try FileManager.default.contentsOfDirectory(
        at: URL(fileURLWithPath: resourcePath),
        includingPropertiesForKeys: nil,
        options: .skipsHiddenFiles
      )

      return files.first(where: {
        $0.lastPathComponent.hasPrefix("\(id)-") && $0.pathExtension == "bytes"
      })
    } catch {
      return nil
    }
  }
}
