import Foundation
import RealityKit

extension Entity {
  public var immersalMapComponent: ImmersalMapComponent? {
    get { components[ImmersalMapComponent.self] }
    set { components[ImmersalMapComponent.self] = newValue }
  }
}
