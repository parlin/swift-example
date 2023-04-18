import SwiftUI
import LiveKit
import SFSafeSymbols

struct AudioTrackPublicationView: View {

    @ObservedObject var trackPublication: TrackPublication
    @EnvironmentObject var appCtx: AppContext

    var body: some View {
        // is remote
        if let remoteTrackPublication = trackPublication as? RemoteTrackPublication {
            Menu {
                if case .subscribed = remoteTrackPublication.subscriptionState {
                    Button {
                        remoteTrackPublication.set(subscribed: false)
                    } label: {
                        Text("Unsubscribe")
                    }
                } else if case .unsubscribed = remoteTrackPublication.subscriptionState {
                    Button {
                        remoteTrackPublication.set(subscribed: true)
                    } label: {
                        Text("Subscribe")
                    }

                }
            } label: {
                if case .subscribed = remoteTrackPublication.subscriptionState, !remoteTrackPublication.muted {
                    Image(systemSymbol: .micFill)
                        .foregroundColor(Color.orange)
                } else if case .notAllowed = remoteTrackPublication.subscriptionState {
                    Image(systemSymbol: .exclamationmarkCircle)
                        .foregroundColor(Color.red)
                } else {
                    Image(systemSymbol: .micSlashFill)
                }
            }
            #if os(macOS)
            .menuStyle(BorderlessButtonMenuStyle(showsMenuIndicator: true))
            #elseif os(iOS)
            .menuStyle(BorderlessButtonMenuStyle())
            #endif
            .fixedSize()
        } else {
            // local
            Image(systemSymbol: .micFill)
                .foregroundColor(Color.orange)
        }
    }
}
