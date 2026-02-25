import CoreImage
import Foundation

enum ColorProfile: String, CaseIterable, Identifiable {
    case sRGB = "sRGB"
    case displayP3 = "Display P3"
    case adobeRGB = "Adobe RGB"

    var id: String { rawValue }

    var cgColorSpace: CGColorSpace {
        switch self {
        case .sRGB:      return CGColorSpace(name: CGColorSpace.sRGB)!
        case .displayP3: return CGColorSpace(name: CGColorSpace.displayP3)!
        case .adobeRGB:  return CGColorSpace(name: CGColorSpace.adobeRGB1998)!
        }
    }
}

enum WhiteBalance: String, CaseIterable, Identifiable {
    case asShot     = "As Shot"
    case auto       = "Auto"
    case daylight   = "Daylight"
    case shade      = "Shade"
    case cloudy     = "Cloudy"
    case tungsten   = "Tungsten"
    case fluorescent = "Fluorescent"
    case flash      = "Flash"

    var id: String { rawValue }

    /// Returns the colour temperature in Kelvin, or nil for As Shot / Auto.
    var kelvin: Float? {
        switch self {
        case .asShot, .auto: return nil
        case .daylight:      return 5500
        case .shade:         return 7500
        case .cloudy:        return 6500
        case .tungsten:      return 3200
        case .fluorescent:   return 4000
        case .flash:         return 5500
        }
    }
}

class ExportSettings: ObservableObject {
    @Published var quality: Double = 0.85
    @Published var maxDimensionEnabled: Bool = false
    @Published var maxDimension: Int = 2000
    @Published var outputFolder: URL? = nil
    @Published var colorProfile: ColorProfile = .sRGB
    @Published var whiteBalance: WhiteBalance = .asShot
    @Published var exposure: Double = 0.0

    /// Settings that affect rendered pixel appearance (thumbnail/preview invalidation).
    var renderKey: RenderKey {
        RenderKey(
            colorProfile: colorProfile,
            whiteBalance: whiteBalance,
            exposure: exposure
        )
    }
}

struct RenderKey: Equatable {
    let colorProfile: ColorProfile
    let whiteBalance: WhiteBalance
    let exposure: Double
}
