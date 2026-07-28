//
//  shengciWidgetLiveActivity.swift
//  shengciWidget
//
//  Created by SM on 28/07/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct shengciWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct shengciWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: shengciWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension shengciWidgetAttributes {
    fileprivate static var preview: shengciWidgetAttributes {
        shengciWidgetAttributes(name: "World")
    }
}

extension shengciWidgetAttributes.ContentState {
    fileprivate static var smiley: shengciWidgetAttributes.ContentState {
        shengciWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: shengciWidgetAttributes.ContentState {
         shengciWidgetAttributes.ContentState(emoji: "🤩")
     }
}

// #Preview("Notification", as: .content, using: shengciWidgetAttributes.preview) {
//    shengciWidgetLiveActivity()
// } contentStates: {
//     shengciWidgetAttributes.ContentState.smiley
//     shengciWidgetAttributes.ContentState.starEyes
// }

