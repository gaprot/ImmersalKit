import Foundation
import PosePlugin
import RealityKit
import os.log

/// Swift interface to Immersal core functionality
internal enum Core {

  // MARK: - On-Device Mapping

  /// Adds image to map
  public static func mapAddImage(
    pixels: UnsafeMutableRawPointer,
    width: Int32,
    height: Int32,
    channels: Int32,
    intrinsics: inout SIMD4<Float>,
    position: inout SIMD3<Float>,
    rotation: inout simd_quatf
  ) -> Int32 {
    var intrinsicsArray: [Float] = [intrinsics[0], intrinsics[1], intrinsics[2], intrinsics[3]]
    var positionArray: [Float] = [position.x, position.y, position.z]
    var rotationArray: [Float] = [
      rotation.vector.x, rotation.vector.y, rotation.vector.z, rotation.vector.w,
    ]

    return icvMapAddImage(
      pixels,
      width,
      height,
      channels,
      &intrinsicsArray,
      &positionArray,
      &rotationArray
    )
  }

  public static func mapImageGetCount() -> Int32 {
    return icvMapImageGetCount()
  }

  public static func mapPrepare(path: String) -> Int32 {
    return icvMapPrepare(path)
  }

  public static func mapGet(map: [UInt8]) -> Int32 {
    var mutableMap = map
    return icvMapGet(&mutableMap)
  }

  public static func mapPointsGetCount() -> Int32 {
    return icvMapPointsGetCount()
  }

  public static func mapPointsGet(points: inout [SIMD3<Float>]) -> Int32 {
    let pointsCount = points.count
    var floatArray = [Float](repeating: 0, count: pointsCount * 3)

    let count = icvMapPointsGet(&floatArray, Int32(pointsCount))

    for i in 0..<min(Int(count) / 3, pointsCount) {
      points[i] = SIMD3<Float>(
        floatArray[i * 3],
        floatArray[i * 3 + 1],
        floatArray[i * 3 + 2]
      )
    }

    return count
  }

  public static func mapResourcesFree() -> Int32 {
    return icvMapResourcesFree()
  }

  // MARK: - Map Operations

  public static func getPointCloud(mapId: Int, points: inout [SIMD3<Float>]) -> Int32 {
    guard let handle = MapHandleMapping.getHandle(for: mapId) else {
      return -1
    }

    let pointsCount = points.count
    var floatArray = [Float](repeating: 0, count: pointsCount * 3)

    let count = icvPointsGet(handle, &floatArray, Int32(pointsCount))

    for i in 0..<min(Int(count) / 3, pointsCount) {
      points[i] = SIMD3<Float>(
        floatArray[i * 3],
        floatArray[i * 3 + 1],
        floatArray[i * 3 + 2]
      )
    }

    return count
  }

  public static func getPointCloudSize(mapId: Int) -> Int32 {
    guard let handle = MapHandleMapping.getHandle(for: mapId) else {
      return -1
    }

    return icvPointsGetCount(handle)
  }

  public static func loadMap(mapId: Int, buffer: UnsafePointer<Int8>) -> Int32 {
    if let handle = MapHandleMapping.getHandle(for: mapId) {
      Logger.mapManagement.info("Map \(mapId)(\(handle)) already loaded")
      return handle
    }

    let mapHandle = icvLoadMap(buffer)
    MapHandleMapping.addMapping(mapId: mapId, pluginHandle: mapHandle)
    Logger.mapManagement.info("Map \(mapId)(\(mapHandle)) loaded")
    return mapHandle
  }

  public static func freeMap(mapId: Int) -> Int32 {
    guard let mapHandle = MapHandleMapping.getHandle(for: mapId) else {
      return 0
    }

    Logger.mapManagement.info("Freeing map \(mapId)(\(mapHandle))")
    MapHandleMapping.removeMappingByMapId(mapId)
    return icvFreeMap(mapHandle)
  }

  // MARK: - Localization

  public static func localizeImage(
    mapIds: [Int],
    width: Int32,
    height: Int32,
    intrinsics: UnsafePointer<Float>,
    pixels: UnsafeMutableRawPointer,
    channels: Int32,
    solverType: Int32,
    cameraRotation: inout simd_quatf
  ) -> LocalizeInfo {
    guard let handles = MapHandleMapping.idsToHandles(mapIds) else {
      return LocalizeInfo(
        handle: -1, position: PPVector3(), rotation: PPQuaternion(), confidence: 0)
    }

    var rotArray: [Float] = [
      cameraRotation.vector.x, cameraRotation.vector.y, cameraRotation.vector.z,
      cameraRotation.vector.w,
    ]

    var mutableHandles = handles
    return icvLocalize(
      Int32(handles.count),
      &mutableHandles,
      width,
      height,
      UnsafeMutablePointer(mutating: intrinsics),
      pixels,
      channels,
      solverType,
      &rotArray
    )
  }

  public static func localizeImage(
    width: Int32,
    height: Int32,
    intrinsics: UnsafePointer<Float>,
    pixels: UnsafeMutableRawPointer
  ) -> LocalizeInfo {
    let mapIds = [0]
    let channels: Int32 = 1
    var cameraRotation = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
    return localizeImage(
      mapIds: mapIds,
      width: width,
      height: height,
      intrinsics: intrinsics,
      pixels: pixels,
      channels: channels,
      solverType: 0,
      cameraRotation: &cameraRotation
    )
  }

  // MARK: - Coordinate Transformation

  /// Convert map coordinates to ECEF coordinates
  public static func posMapToEcef(
    ecef: inout [Double],
    map: SIMD3<Float>,
    mapToEcef: [Double]
  ) -> Int32 {
    var mapArray: [Float] = [map.x, map.y, map.z]
    var mapToEcefCopy = mapToEcef
    return icvPosMapToEcef(&ecef, &mapArray, &mapToEcefCopy)
  }

  /// Convert ECEF coordinates to WGS84 coordinates
  public static func posEcefToWgs84(
    wgs84: inout [Double],
    ecef: [Double]
  ) -> Int32 {
    var ecefCopy = ecef
    return icvPosEcefToWgs84(&wgs84, &ecefCopy)
  }

  /// Convert WGS84 coordinates to ECEF coordinates
  public static func posWgs84ToEcef(
    ecef: inout [Double],
    wgs84: [Double]
  ) -> Int32 {
    var wgs84Copy = wgs84
    return icvPosWgs84ToEcef(&ecef, &wgs84Copy)
  }

  /// Convert ECEF coordinates to map coordinates
  public static func posEcefToMap(
    map: inout SIMD3<Float>,
    ecef: [Double],
    mapToEcef: [Double]
  ) -> Int32 {
    var ecefCopy = ecef
    var mapToEcefCopy = mapToEcef
    var mapArray = [Float](repeating: 0, count: 3)

    let result = icvPosEcefToMap(&mapArray, &ecefCopy, &mapToEcefCopy)

    // Convert result to SIMD3<Float>
    if result == 1 {
      map = SIMD3<Float>(mapArray[0], mapArray[1], mapArray[2])
    }

    return result
  }

  /// Convert map coordinates to WGS84 coordinates
  public static func posMapToWgs84(
    wgs84: inout [Double],
    map: SIMD3<Float>,
    mapToEcef: [Double]
  ) -> Int32 {
    var ecef = [Double](repeating: 0, count: 3)
    let err = posMapToEcef(ecef: &ecef, map: map, mapToEcef: mapToEcef)
    if err != 0 {
      return err
    }
    return posEcefToWgs84(wgs84: &wgs84, ecef: ecef)
  }

  /// Convert map rotation to ECEF rotation
  public static func rotMapToEcef(
    ecef: inout simd_quatf,
    map: simd_quatf,
    mapToEcef: [Double]
  ) -> Int32 {
    // Convert quaternion to Float array
    var mapArray: [Float] = [map.vector.x, map.vector.y, map.vector.z, map.vector.w]
    var ecefArray = [Float](repeating: 0, count: 4)
    var mapToEcefCopy = mapToEcef

    let result = icvRotMapToEcef(&ecefArray, &mapArray, &mapToEcefCopy)

    // Convert result to simd_quatf
    if result == 1 {
      ecef = simd_quatf(ix: ecefArray[0], iy: ecefArray[1], iz: ecefArray[2], r: ecefArray[3])
    }

    return result
  }

  /// Convert ECEF rotation to map rotation
  public static func rotEcefToMap(
    map: inout simd_quatf,
    ecef: simd_quatf,
    mapToEcef: [Double]
  ) -> Int32 {
    // Convert quaternion to Float array
    var ecefArray: [Float] = [ecef.vector.x, ecef.vector.y, ecef.vector.z, ecef.vector.w]
    var mapArray = [Float](repeating: 0, count: 4)
    var mapToEcefCopy = mapToEcef

    let result = icvRotEcefToMap(&mapArray, &ecefArray, &mapToEcefCopy)

    // Convert result to simd_quatf
    if result == 1 {
      map = simd_quatf(ix: mapArray[0], iy: mapArray[1], iz: mapArray[2], r: mapArray[3])
    }

    return result
  }

  // MARK: - Plugin Settings

  /// Get plugin integer parameter
  public static func getInteger(parameter: String) -> Int32 {
    return icvGetInteger(parameter)
  }

  /// Set plugin integer parameter
  public static func setInteger(parameter: String, value: Int32) -> Int32 {
    return icvSetInteger(parameter, value)
  }

  /// Validate user token
  public static func validateUser(token: String) -> Int32 {
    return icvValidateUser(token)
  }
}
