//
//  UITextMeasurer.swift
//  MeditateAndNote
//
//  UIFont-backed `TextMeasurer` for the pagination engine.
//

import UIKit
import MeditateAndNoteCore

struct UITextMeasurer: TextMeasurer {
    let font: UIFont
    let lineHeightMultiple: CGFloat

    init(fontSize: CGFloat, lineHeightMultiple: CGFloat = 1.45) {
        let descriptor = UIFontDescriptor
            .preferredFontDescriptor(withTextStyle: .body)
            .withDesign(.serif)?
            .withSize(fontSize)
        self.font = UIFont(descriptor: descriptor ?? .init(), size: fontSize)
        self.lineHeightMultiple = lineHeightMultiple
    }

    func width(of text: String) -> Double {
        Double((text as NSString).size(withAttributes: [.font: font]).width)
    }

    func lineHeight() -> Double {
        Double(font.lineHeight * lineHeightMultiple)
    }
}
