//
//  SkillDecayWidgetsBundle.swift
//  SkillDecayWidgets
//
//  Created by Pavel Kulitski on 01.04.2026.
//

import WidgetKit
import SwiftUI

@main
struct SkillDecayWidgetsBundle: WidgetBundle {
    var body: some Widget {
        SkillSpotlightWidget()   // Small  — most urgent skill
        DailyOverviewWidget()    // Medium — top 3 skills + streak
        SkillMapMiniWidget()     // Large  — full dot grid
        LockScreenWidget()       // Lock Screen — circular + rectangular
    }
}
