import Foundation
import RealityKit
import SwiftUI

public struct ImmersalMapComponent: Component, Codable {
  public var mapId: Int = -1

  public init() {
    mapId = -1
  }

  public init(mapId: Int) {
    self.mapId = mapId
  }

  enum CodingKeys: String, CodingKey {
    case mapId
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    mapId = try container.decode(Int.self, forKey: .mapId)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(mapId, forKey: .mapId)
  }
}
