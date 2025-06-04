import Foundation

// MARK: - Utility Extensions

extension Double {
  func rounded(to places: Int) -> Double {
    let multiplier = pow(10.0, Double(places))
    return (self * multiplier).rounded() / multiplier
  }
}
