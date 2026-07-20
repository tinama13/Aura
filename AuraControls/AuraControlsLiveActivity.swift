//
//  AuraControlsLiveActivity.swift
//  AuraControls
//
//  Created by 11 BGCC Loan Library on 7/20/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct AuraControlsAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct AuraControlsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AuraControlsAttributes.self) { context in
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

extension AuraControlsAttributes {
    fileprivate static var preview: AuraControlsAttributes {
        AuraControlsAttributes(name: "World")
    }
}

extension AuraControlsAttributes.ContentState {
    fileprivate static var smiley: AuraControlsAttributes.ContentState {
        AuraControlsAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: AuraControlsAttributes.ContentState {
         AuraControlsAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: AuraControlsAttributes.preview) {
   AuraControlsLiveActivity()
} contentStates: {
    AuraControlsAttributes.ContentState.smiley
    AuraControlsAttributes.ContentState.starEyes
}
