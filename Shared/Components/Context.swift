import SwiftUI
import LiveKit

// Scope for LiveKit Components
struct LiveKitComponents {
    //
    struct RoomView: View {

        @EnvironmentObject var roomCtx: RoomContext

        var body: some View {
            Text("RoomView")
        }
    }
}
