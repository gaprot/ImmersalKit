import Foundation
import RealityKit

extension Entity {
  func forEachDescendant<T: Component>(
    withComponent componentClass: T.Type, _ closure: (Entity, T) -> Void
  ) {
    for child in children {
      if let component = child.components[componentClass] {
        closure(child, component)
      }
      child.forEachDescendant(withComponent: componentClass, closure)
    }
  }
}
