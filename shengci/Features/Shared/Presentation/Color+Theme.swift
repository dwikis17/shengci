//
//  Color+Theme.swift
//  shengci
//

import SwiftUI
import UIKit

// MARK: - Dynamic Theme Color Palette Extension (Light & Dark Mode)
extension Color {
    static let creamBackground = Color(UIColor.creamBackground)
    static let warmIvoryCard = Color(UIColor.warmIvoryCard)
    static let darkForeground = Color(UIColor.darkForeground)
    static let royalBlueAccent = Color(UIColor.royalBlueAccent)
    static let tealAccent = Color(UIColor.tealAccent)
    static let amberAccent = Color(UIColor.amberAccent)
    static let roseAccent = Color(UIColor.roseAccent)
}

extension UIColor {
    static let creamBackground = UIColor { traitCollection in
        switch traitCollection.userInterfaceStyle {
        case .dark:
            return UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0) // Deep Dark Charcoal (#1C1C1E)
        default:
            return UIColor(red: 0.97, green: 0.95, blue: 0.92, alpha: 1.0) // Warm Cream (#FAF2EA)
        }
    }

    static let warmIvoryCard = UIColor { traitCollection in
        switch traitCollection.userInterfaceStyle {
        case .dark:
            return UIColor(red: 0.17, green: 0.17, blue: 0.18, alpha: 1.0) // Dark Card Surface (#2C2C2E)
        default:
            return UIColor(red: 1.0, green: 0.99, blue: 0.97, alpha: 1.0) // Soft Ivory White (#FFFCF7)
        }
    }

    static let darkForeground = UIColor { traitCollection in
        switch traitCollection.userInterfaceStyle {
        case .dark:
            return UIColor(red: 0.94, green: 0.92, blue: 0.90, alpha: 1.0) // Soft Cream Off-White (#F0EBE6)
        default:
            return UIColor(red: 0.15, green: 0.13, blue: 0.12, alpha: 1.0) // Deep Espresso Charcoal (#26211F)
        }
    }

    static let royalBlueAccent = UIColor { traitCollection in
        switch traitCollection.userInterfaceStyle {
        case .dark:
            return UIColor(red: 0.40, green: 0.60, blue: 1.0, alpha: 1.0) // Vibrant Royal Blue (#6699FF)
        default:
            return UIColor(red: 0.20, green: 0.40, blue: 0.80, alpha: 1.0) // Slate Royal Blue (#3366CC)
        }
    }

    static let tealAccent = UIColor { traitCollection in
        switch traitCollection.userInterfaceStyle {
        case .dark:
            return UIColor(red: 0.30, green: 0.75, blue: 0.65, alpha: 1.0) // Vibrant Sage Teal (#4DBEA6)
        default:
            return UIColor(red: 0.12, green: 0.60, blue: 0.50, alpha: 1.0) // Warm Sage Teal (#1F9980)
        }
    }

    static let amberAccent = UIColor { traitCollection in
        switch traitCollection.userInterfaceStyle {
        case .dark:
            return UIColor(red: 0.95, green: 0.65, blue: 0.25, alpha: 1.0) // Terracotta Amber (#F3A640)
        default:
            return UIColor(red: 0.82, green: 0.50, blue: 0.10, alpha: 1.0) // Terracotta Amber (#D1801A)
        }
    }

    static let roseAccent = UIColor { traitCollection in
        switch traitCollection.userInterfaceStyle {
        case .dark:
            return UIColor(red: 0.95, green: 0.40, blue: 0.45, alpha: 1.0) // Crimson Rose (#F26673)
        default:
            return UIColor(red: 0.85, green: 0.25, blue: 0.32, alpha: 1.0) // Crimson Rose (#D94052)
        }
    }
}
