import RealityKit

public struct CameraParameters {
  public let fx: Double
  public let fy: Double
  public let ox: Double
  public let oy: Double

  public init(fx: Double, fy: Double, ox: Double, oy: Double) {
    self.fx = fx
    self.fy = fy
    self.ox = ox
    self.oy = oy
  }

  public init(fx: Float, fy: Float, ox: Float, oy: Float) {
    self.fx = Double(fx)
    self.fy = Double(fy)
    self.ox = Double(ox)
    self.oy = Double(oy)
  }
}

public struct LocalizeB64Request: Codable {
  public struct MapIdWrapper: Codable {
    public let id: Int

    public init(id: Int) {
      self.id = id
    }
  }

  public let mapIds: [MapIdWrapper]
  public let b64: String
  public let oy: Double
  public let ox: Double
  public let fy: Double
  public let token: String?
  public let fx: Double

  public init(
    mapIds: [MapId],
    b64: String,
    oy: Double,
    ox: Double,
    fy: Double,
    token: String?,
    fx: Double
  ) {
    // Convert integer array to MapIdWrapper object array
    self.mapIds = mapIds.map { MapIdWrapper(id: $0) }
    self.b64 = b64
    self.oy = oy
    self.ox = ox
    self.fy = fy
    self.token = token
    self.fx = fx
  }
}

public struct LocalizeResponse: Codable {
  public let error: String
  public let success: Bool?
  public let map: Int?
  public let px: Float?
  public let py: Float?
  public let pz: Float?
  public let r00: Float?
  public let r01: Float?
  public let r02: Float?
  public let r10: Float?
  public let r11: Float?
  public let r12: Float?
  public let r20: Float?
  public let r21: Float?
  public let r22: Float?

  public var position: simd_float3? {
    guard let px, let py, let pz else { return nil }
    return simd_float3(px, py, pz)
  }

  public var rotationMatrix: simd_float3x3? {
    guard let r00, let r01, let r02,
      let r10, let r11, let r12,
      let r20, let r21, let r22
    else {
      return nil
    }

    return simd_float3x3(
      simd_float3(r00, r01, r02),
      simd_float3(r10, r11, r12),
      simd_float3(r20, r21, r22)
    )
  }

  /// Convert rotation matrix to quaternion
  public var rotation: simd_quatf? {
    guard let rotMatrix = rotationMatrix else { return nil }
    return simd_quatf(rotMatrix)
  }

  /// Get position and rotation as tuple
  public var pose: (position: simd_float3?, rotation: simd_quatf?) {
    return (position, rotation)
  }

  public var isSuccess: Bool {
    error == "none" && success == true
  }
}
public struct LoginRequest: Codable {
  public let login: String
  public let password: String
}

public struct LoginResponse: Codable {
  public let error: String
  public let userId: Int?
  public let token: String?

  public var isSuccess: Bool {
    error == "none" && userId != nil && token != nil
  }
}

public struct StatusRequest: Codable {
  public let token: String
}

public struct StatusResponse: Codable {
  public let error: String
  public let userId: Int?
  public let imageCount: Int?
  public let imageMax: Int?
  public let eulaAccepted: Bool?

  public var isSuccess: Bool {
    error == "none" && userId != nil
  }
}

public struct ListRequest: Codable {
  public let token: String
}

public struct Job: Codable, Identifiable {
  public let id: Int
  public let type: Int
  public let version: String
  public let creator: Int
  public let size: Int
  public let status: String
  public let errno: Int
  public let privacy: Int
  public let name: String
  public let latitude: Double?
  public let longitude: Double?
  public let altitude: Double?
  public let created: String
  public let modified: String
  public let sha256_al: String?
  public let sha256_sparse: String?
  public let sha256_dense: String?
  public let sha256_tex: String?
}

public struct JobsResponse: Codable {
  public let error: String
  public let count: Int?
  public let jobs: [Job]?
}

public struct ErrorResponse: Codable {
  public let error: String
}

public struct BasicResponse: Codable {
  public let error: String

  public var isSuccess: Bool {
    error == "none"
  }
}

public struct VersionResponse: Codable {
  public let error: String
  public let version: String?
}

extension CameraParameters {
  /// Returns camera parameter values obtained from actual Vision Pro device
  public static var visionProMock: CameraParameters {
    CameraParameters(
      fx: 736.6339111328125,
      fy: 736.6339111328125,
      ox: 540.0,
      oy: 540.0
    )
  }
}
