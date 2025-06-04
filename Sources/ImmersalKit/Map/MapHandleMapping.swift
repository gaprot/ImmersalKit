import Foundation
import RealityKit

/// Manages map handle mapping between plugin handles and map IDs
internal final class MapHandleMapping {
  private static var mapIdToHandleMapping: [MapId: MapHandle] = [:]
  private static var handleToMapIdMapping: [MapHandle: MapId] = [:]

  /// Add mapping between map ID and plugin handle
  public static func addMapping(mapId: MapId, pluginHandle: MapHandle) {
    if mapIdToHandleMapping[mapId] != nil || handleToMapIdMapping[pluginHandle] != nil {
      return
    }

    mapIdToHandleMapping[mapId] = pluginHandle
    handleToMapIdMapping[pluginHandle] = mapId
  }

  /// Get plugin handle for map ID
  public static func getHandle(for mapId: MapId) -> MapHandle? {
    return mapIdToHandleMapping[mapId]
  }

  /// Get map ID for plugin handle
  public static func getMapId(for pluginHandle: MapHandle) -> MapId? {
    return handleToMapIdMapping[pluginHandle]
  }

  /// Remove mapping by map ID
  @discardableResult
  public static func removeMappingByMapId(_ mapId: MapId) -> Bool {
    guard let pluginHandle = mapIdToHandleMapping[mapId] else {
      return false
    }

    mapIdToHandleMapping.removeValue(forKey: mapId)
    handleToMapIdMapping.removeValue(forKey: pluginHandle)
    return true
  }

  /// Clear all mappings
  @discardableResult
  public static func clear() -> Bool {
    let mapIds = Array(mapIdToHandleMapping.keys)
    for mapId in mapIds {
      if !removeMappingByMapId(mapId) {
        return false
      }
    }

    return true
  }

  /// Convert map IDs to plugin handles
  public static func idsToHandles(_ mapIds: [MapId]) -> [MapHandle]? {
    var handles = [Int32](repeating: 0, count: mapIds.count)

    // Special case for single 0 ID
    if mapIds.count == 1 && mapIds[0] == 0 {
      handles[0] = 0
      return handles
    }

    for (i, mapId) in mapIds.enumerated() {
      guard let handle = getHandle(for: mapId) else {
        return nil
      }
      handles[i] = handle
    }

    return handles
  }
}
