//
//  MapManagementError.swift
//  ImmersalKit
//
//  Created by ryudai.kimura on 2025/05/27.
//

import ARKit
import Foundation

/// Errors related to map management operations.
public enum MapManagementError: Error, LocalizedError, Equatable {
  case mapNotFound(MapId)
  case mapLoadFailed(MapId, String)
  case mapUnloadFailed(MapId, String)
  case invalidMapData(MapId)
  case mapAlreadyLoaded(MapId)
  case pointCloudGenerationFailed(MapId)

  public var errorDescription: String? {
    switch self {
    case .mapNotFound(let mapId):
      return "Map (ID: \(mapId)) not found"
    case .mapLoadFailed(let mapId, let reason):
      return "Failed to load map (ID: \(mapId)): \(reason)"
    case .mapUnloadFailed(let mapId, let reason):
      return "Failed to unload map (ID: \(mapId)): \(reason)"
    case .invalidMapData(let mapId):
      return "Invalid data for map (ID: \(mapId))"
    case .mapAlreadyLoaded(let mapId):
      return "Map (ID: \(mapId)) is already loaded"
    case .pointCloudGenerationFailed(let mapId):
      return "Point cloud generation failed for map (ID: \(mapId))"
    }
  }

  public var failureReason: String? {
    switch self {
    case .mapNotFound(let mapId):
      return "No map file or entry exists for the specified map ID \(mapId)"
    case .mapLoadFailed(let mapId, let reason):
      return "An error occurred during loading process for map ID \(mapId): \(reason)"
    case .mapUnloadFailed(let mapId, let reason):
      return "An error occurred during unloading process for map ID \(mapId): \(reason)"
    case .invalidMapData(let mapId):
      return "Data for map ID \(mapId) is corrupted or has incorrect format"
    case .mapAlreadyLoaded(let mapId):
      return "Map ID \(mapId) is already loaded in memory"
    case .pointCloudGenerationFailed(let mapId):
      return "An error occurred while generating point cloud data from map ID \(mapId)"
    }
  }

  public var recoverySuggestion: String? {
    switch self {
    case .mapNotFound(_):
      return "Please verify that map files are correctly placed and use valid map IDs."
    case .mapLoadFailed(_, _):
      return "Please check map file integrity and close other apps if memory is insufficient."
    case .mapUnloadFailed(_, _):
      return "Please wait a moment and retry, or restart the app."
    case .invalidMapData(_):
      return "Please use correct map files and verify that files are not corrupted."
    case .mapAlreadyLoaded(_):
      return "Please reuse the already loaded map or unload it first before reloading."
    case .pointCloudGenerationFailed(_):
      return "Please check device memory and GPU performance, and reduce point cloud density."
    }
  }
}
