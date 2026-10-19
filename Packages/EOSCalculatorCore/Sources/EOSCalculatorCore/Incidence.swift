import Foundation

/// Baseline incidence of culture-confirmed EOS, in cases per 1000 live births.
/// The options mirror the KP web calculator's drop-down.
public struct Incidence: Hashable, Codable, Sendable, Identifiable {
    public let per1000: Double

    public init(per1000: Double) {
        self.per1000 = per1000
    }

    public var id: Double { per1000 }

    /// Incidence as a probability (cases per live birth).
    public var probability: Double { per1000 / 1000.0 }

    /// Kaiser Permanente Northern California incidence (the calculator's default).
    public static let kpnc = Incidence(per1000: 0.3)
    /// CDC national incidence as labelled on the KP calculator.
    public static let cdcNational = Incidence(per1000: 0.5)

    public static let options: [Incidence] = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 2.0, 4.0]
        .map(Incidence.init(per1000:))

    public var label: String {
        var text = "\(Self.format(per1000))/1000 live births"
        if self == .kpnc {
            text += " (KPNC incidence)"
        } else if self == .cdcNational {
            text += " (CDC national incidence)"
        }
        return text
    }

    public var shortLabel: String { "\(Self.format(per1000))/1000" }

    private static func format(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}
