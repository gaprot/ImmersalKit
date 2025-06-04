import simd

extension simd_float4x4 {
  /// Create transformation matrix from position and rotation (scale 1.0)
  /// - Parameters:
  ///   - position: Position vector
  ///   - rotation: Rotation quaternion
  /// - Returns: Transformation matrix
  init(position: simd_float3, rotation: simd_quatf) {
    let rotMatrix = simd_matrix4x4(rotation)
    self.init(
      SIMD4<Float>(rotMatrix[0][0], rotMatrix[0][1], rotMatrix[0][2], 0),
      SIMD4<Float>(rotMatrix[1][0], rotMatrix[1][1], rotMatrix[1][2], 0),
      SIMD4<Float>(rotMatrix[2][0], rotMatrix[2][1], rotMatrix[2][2], 0),
      SIMD4<Float>(position.x, position.y, position.z, 1)
    )
  }

}
