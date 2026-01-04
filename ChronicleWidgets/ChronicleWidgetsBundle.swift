//
//  ChronicleWidgetsBundle.swift
//  ChronicleWidgets
//
//  Created by Jean Flaherty on 2026/01/04.
//

import WidgetKit
import SwiftUI

@main
struct ChronicleWidgetsBundle: WidgetBundle {
    var body: some Widget {
        ActiveTaskWidget()
        FavoriteTasksWidget()
        CombinedTaskWidget()
        ChronicleWidgetsControl()
    }
}
