import SwiftUI
import LiveKit
import SFSafeSymbols

struct VideoTrackPublicationView: View {

    @ObservedObject var trackPublication: TrackPublication
    @EnvironmentObject var appCtx: AppContext

    @State private var isRendering: Bool = false
    @State private var dimensions: Dimensions?
    @State private var videoTrackStats: TrackStats?

    var body: some View {
        GeometryReader { geometry in

            ZStack(alignment: .topTrailing) {
                // Background color
                Color.lkGray1
                    .ignoresSafeArea()

                if  !trackPublication.muted,
                    let track = trackPublication.track as? VideoTrack,
                    trackPublication.subscribed,
                    appCtx.videoViewVisible {

                    SwiftUIVideoView(track,
                                     layoutMode: appCtx.videoViewMode,
                                     mirrorMode: appCtx.videoViewMirrored ? .mirror : .auto,
                                     debugMode: false, // appCtx.showInformationOverlay,
                                     isRendering: $isRendering,
                                     dimensions: $dimensions,
                                     trackStats: $videoTrackStats)

                    if !isRendering {
                        ProgressView().progressViewStyle(CircularProgressViewStyle())
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    }

                } else if let remoteTrackPublication = trackPublication as? RemoteTrackPublication,
                          case .notAllowed = remoteTrackPublication.subscriptionState {
                    // Show no permission icon
                    bgView(systemSymbol: .exclamationmarkCircle, geometry: geometry)
                } else {
                    // Show no camera icon
                    bgView(systemSymbol: .videoSlashFill, geometry: geometry)
                }

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
                            Image(systemSymbol: .videoFill)
                                .foregroundColor(Color.green)
                        } else if case .notAllowed = remoteTrackPublication.subscriptionState {
                            Image(systemSymbol: .exclamationmarkCircle)
                                .foregroundColor(Color.red)
                        } else {
                            Image(systemSymbol: .videoSlashFill)
                        }
                    }
                    #if os(macOS)
                    .menuStyle(BorderlessButtonMenuStyle(showsMenuIndicator: true))
                    #elseif os(iOS)
                    .menuStyle(BorderlessButtonMenuStyle())
                    #endif
                    .fixedSize()
                    .padding(8)
                } else {
                    // local
                    Image(systemSymbol: .videoFill)
                        .foregroundColor(Color.green)
                        .padding(8)
                }

                if appCtx.showInformationOverlay {

                    VStack(alignment: .leading, spacing: 5) {
                        // Video stats
                        if let track = trackPublication.track as? VideoTrack, !trackPublication.muted {
                            StatsView(track: track)
                        }
                        //                                        // Audio stats
                        //                                        if let publication = participant.firstAudioPublication,
                        //                                           !publication.muted,
                        //                                           let track = publication.track as? AudioTrack {
                        //                                            StatsView(track: track)
                        //                                        }
                    }
                    .padding(8)
                    .frame(
                        minWidth: 0,
                        maxWidth: .infinity,
                        minHeight: 0,
                        maxHeight: .infinity,
                        alignment: .topLeading
                    )
                }
            }
        }
    }
}
