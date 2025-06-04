import RealityKit

extension JobsResponse {
  public var debugString: String {
    var components: [String] = []

    components.append("JobsResponse {")
    components.append("  error: \"\(error)\"")
    components.append("  count: \(count?.description ?? "nil")")

    if let jobs = jobs {
      components.append("  jobs: [")
      if jobs.isEmpty {
        components.append("    (empty)")
      } else {
        // Show only first 3 jobs (if too many)
        let displayJobs = jobs.count > 3 ? Array(jobs.prefix(3)) : jobs
        for job in displayJobs {
          // Show only basic job information
          components.append(
            "    Job(id: \(job.id), name: \"\(job.name)\", status: \"\(job.status)\")")
        }

        if jobs.count > 3 {
          components.append("    ... (\(jobs.count - 3) more jobs)")
        }
      }
      components.append("  ]")
    } else {
      components.append("  jobs: nil")
    }

    components.append("}")

    return components.joined(separator: "\n")
  }
}
extension LocalizeB64Request {
  public var debugString: String {
    var components: [String] = []

    components.append("LocalizeB64Request {")

    // Map IDs
    components.append("  mapIds: [")
    for mapId in mapIds {
      components.append("    \(mapId.id)")
    }
    components.append("  ]")

    // Base64 image data (truncated for readability)
    let truncatedB64 =
      b64.count > 20
      ? "\(b64.prefix(20))...(length: \(b64.count))"
      : b64
    components.append("  b64: \"\(truncatedB64)\"")

    // Camera parameters
    components.append("  fx: \(fx)")
    components.append("  fy: \(fy)")
    components.append("  ox: \(ox)")
    components.append("  oy: \(oy)")

    // Token
    components.append("  token: \(token?.description ?? "nil")")

    components.append("}")

    return components.joined(separator: "\n")
  }
}

extension LoginRequest {
  public var debugString: String {
    var components: [String] = []

    components.append("LoginRequest {")
    components.append("  login: \"\(login)\"")
    // Don't display password for security
    components.append("  password: \"********\"")
    components.append("}")

    return components.joined(separator: "\n")
  }
}
extension LoginResponse {
  public var debugString: String {
    var components: [String] = []

    components.append("LoginResponse {")
    components.append("  error: \"\(error)\"")
    components.append("  userId: \(userId?.description ?? "nil")")

    // Only show if token exists (for security)
    if let token = token {
      components.append("  token: \"********\" (length: \(token.count))")
    } else {
      components.append("  token: nil")
    }

    components.append("  isSuccess: \(isSuccess)")
    components.append("}")

    return components.joined(separator: "\n")
  }
}
extension StatusRequest {
  public var debugString: String {
    var components: [String] = []

    components.append("StatusRequest {")
    // Only show if token exists (for security)
    components.append("  token: \"********\" (length: \(token.count))")
    components.append("}")

    return components.joined(separator: "\n")
  }
}
extension StatusResponse {
  public var debugString: String {
    var components: [String] = []

    components.append("StatusResponse {")
    components.append("  error: \"\(error)\"")
    components.append("  userId: \(userId?.description ?? "nil")")
    components.append("  imageCount: \(imageCount?.description ?? "nil")")
    components.append("  imageMax: \(imageMax?.description ?? "nil")")
    components.append("  eulaAccepted: \(eulaAccepted?.description ?? "nil")")
    components.append("  isSuccess: \(isSuccess)")
    components.append("}")

    return components.joined(separator: "\n")
  }
}
extension ListRequest {
  public var debugString: String {
    var components: [String] = []

    components.append("ListRequest {")
    // Only show if token exists (for security)
    components.append("  token: \"********\" (length: \(token.count))")
    components.append("}")

    return components.joined(separator: "\n")
  }
}
extension Job {
  public var debugString: String {
    var components: [String] = []

    components.append("Job {")
    components.append("  id: \(id)")
    components.append("  name: \"\(name)\"")
    components.append("  type: \(type)")
    components.append("  version: \"\(version)\"")
    components.append("  creator: \(creator)")
    components.append("  size: \(size)")
    components.append("  status: \"\(status)\"")
    components.append("  errno: \(errno)")
    components.append("  privacy: \(privacy)")

    // Location information
    if let latitude = latitude, let longitude = longitude {
      components.append("  location: (\(latitude), \(longitude))")
      if let altitude = altitude {
        components.append("  altitude: \(altitude)")
      }
    } else {
      components.append("  location: nil")
    }

    components.append("  created: \"\(created)\"")
    components.append("  modified: \"\(modified)\"")

    // Hash values (truncated display)
    let hashFields = [
      ("sha256_al", sha256_al),
      ("sha256_sparse", sha256_sparse),
      ("sha256_dense", sha256_dense),
      ("sha256_tex", sha256_tex),
    ]

    for (name, hash) in hashFields {
      if let hash = hash {
        let truncatedHash = hash.count > 10 ? "\(hash.prefix(10))..." : hash
        components.append("  \(name): \"\(truncatedHash)\"")
      } else {
        components.append("  \(name): nil")
      }
    }

    components.append("}")

    return components.joined(separator: "\n")
  }
}
extension ErrorResponse {
  public var debugString: String {
    var components: [String] = []

    components.append("ErrorResponse {")
    components.append("  error: \"\(error)\"")
    components.append("}")

    return components.joined(separator: "\n")
  }
}
extension BasicResponse {
  public var debugString: String {
    var components: [String] = []

    components.append("BasicResponse {")
    components.append("  error: \"\(error)\"")
    components.append("  isSuccess: \(isSuccess)")
    components.append("}")

    return components.joined(separator: "\n")
  }
}
extension VersionResponse {
  public var debugString: String {
    var components: [String] = []

    components.append("VersionResponse {")
    components.append("  error: \"\(error)\"")
    components.append("  version: \(version?.description ?? "nil")")
    components.append("}")

    return components.joined(separator: "\n")
  }
}
extension LocalizeResponse {
  public var debugString: String {
    var components: [String] = []

    // Basic info
    components.append("LocalizeResponse {")
    components.append("  error: \"\(error)\"")
    components.append("  success: \(success?.description ?? "nil")")
    components.append("  isSuccess: \(isSuccess)")
    components.append("  map: \(map?.description ?? "nil")")

    // Position info
    if let position = position {
      components.append("  position: (\(position.x), \(position.y), \(position.z))")
    } else {
      components.append("  position: nil")
      components.append("    px: \(px?.description ?? "nil")")
      components.append("    py: \(py?.description ?? "nil")")
      components.append("    pz: \(pz?.description ?? "nil")")
    }

    // Rotation matrix info
    if let rotationMatrix = rotationMatrix {
      components.append("  rotationMatrix: [")
      components.append(
        "    [\(rotationMatrix[0].x), \(rotationMatrix[0].y), \(rotationMatrix[0].z)]")
      components.append(
        "    [\(rotationMatrix[1].x), \(rotationMatrix[1].y), \(rotationMatrix[1].z)]")
      components.append(
        "    [\(rotationMatrix[2].x), \(rotationMatrix[2].y), \(rotationMatrix[2].z)]")
      components.append("  ]")
    } else {
      components.append("  rotationMatrix: nil")
      components.append(
        "    r00: \(r00?.description ?? "nil"), r01: \(r01?.description ?? "nil"), r02: \(r02?.description ?? "nil")"
      )
      components.append(
        "    r10: \(r10?.description ?? "nil"), r11: \(r11?.description ?? "nil"), r12: \(r12?.description ?? "nil")"
      )
      components.append(
        "    r20: \(r20?.description ?? "nil"), r21: \(r21?.description ?? "nil"), r22: \(r22?.description ?? "nil")"
      )
    }

    components.append("}")

    return components.joined(separator: "\n")
  }
}
