import WidgetKit
import SwiftUI

@main
struct ChronicleWidgetsBundle: WidgetBundle {
    var body: some Widget {
        ActiveTaskWidget()
        FavoriteTasksWidget()
    }
}
