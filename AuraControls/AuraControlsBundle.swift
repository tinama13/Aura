//
//  AuraControlsBundle.swift
//  AuraControls
//

import WidgetKit
import SwiftUI

@main
struct AuraControlsBundle: WidgetBundle {
    var body: some Widget {
        AuraListeningControl()
        AuraPresetOneControl()
        AuraPresetTwoControl()
        AuraPresetThreeControl()
        AuraPresetFourControl()
    }
}
