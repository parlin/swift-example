import SwiftUI
import LiveKit
import SFSafeSymbols

struct ParticipantView: View {

    @ObservedObject var participant: Participant
    @EnvironmentObject var appCtx: AppContext

    // var videoViewMode: VideoView.LayoutMode = .fill
    var onTap: ((_ participant: Participant) -> Void)?

    var body: some View {
        GeometryReader { geometry in

            ZStack(alignment: .bottom) {
                // Background color
                Color.lkGray1
                    .ignoresSafeArea()

                //                // VideoView for the Participant
                if let trackPublication = participant.mainVideoPublication {
                    VideoTrackPublicationView(trackPublication: trackPublication)
                } else {
                    bgView(systemSymbol: .videoSlashFill, geometry: geometry)
                }

                VStack(alignment: .trailing, spacing: 0) {
                    // Show the sub-video view
                    if let subVideoTrackPublication = participant.subVideoPublication {
                        VideoTrackPublicationView(trackPublication: subVideoTrackPublication)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: min(geometry.size.width, geometry.size.height) * 0.3)
                            .cornerRadius(8)
                            .padding()
                    }

                    // Bottom user info bar
                    HStack {
                        Text("\(participant.identity)")
                            .lineLimit(1)
                            .truncationMode(.tail)

                        if let audioTrackPublication = participant.firstAudioPublication {
                            AudioTrackPublicationView(trackPublication: audioTrackPublication)
                        } else {
                            Image(systemSymbol: .micSlashFill)
                                .foregroundColor(Color.white)
                        }

                        if participant.connectionQuality == .excellent {
                            Image(systemSymbol: .wifi)
                                .foregroundColor(.green)
                        } else if participant.connectionQuality == .good {
                            Image(systemSymbol: .wifi)
                                .foregroundColor(Color.orange)
                        } else if participant.connectionQuality == .poor {
                            Image(systemSymbol: .wifiExclamationmark)
                                .foregroundColor(Color.red)
                        }
                    }.padding(5)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .background(Color.black.opacity(0.5))
                }
            }
            .cornerRadius(8)
            // Glow the border when the participant is speaking
            .overlay(
                participant.isSpeaking ?
                    RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.blue, lineWidth: 5.0)
                    : nil
            )
        }.gesture(TapGesture()
                    .onEnded { _ in
                        // Pass the tap event
                        onTap?(participant)
                    })
    }
}

struct StatsView: View {

    @ObservedObject private var viewModel: DelegateObserver
    private let track: Track

    init(track: Track) {
        self.track = track
        viewModel = DelegateObserver(track: track)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 5) {
            VStack(alignment: .leading, spacing: 5) {
                if track is VideoTrack {
                    HStack(spacing: 3) {
                        Image(systemSymbol: .videoFill)
                        Text("Video").fontWeight(.bold)
                        if let dimensions = viewModel.dimensions {
                            Text("\(dimensions.width)×\(dimensions.height)")
                        }
                    }
                } else if track is AudioTrack {
                    HStack(spacing: 3) {
                        Image(systemSymbol: .micFill)
                        Text("Audio").fontWeight(.bold)
                    }
                } else {
                    Text("Unknown").fontWeight(.bold)
                }

                if let trackStats = viewModel.stats {

                    if trackStats.bpsSent != 0 {

                        HStack(spacing: 3) {
                            if let codecName = trackStats.codecName {
                                Text(codecName.uppercased()).fontWeight(.bold)
                            }
                            Image(systemSymbol: .arrowUpCircle)
                            Text(trackStats.formattedBpsSent())
                        }
                    }

                    if trackStats.bpsReceived != 0 {
                        HStack(spacing: 3) {
                            if let codecName = trackStats.codecName {
                                Text(codecName.uppercased()).fontWeight(.bold)
                            }
                            Image(systemSymbol: .arrowDownCircle)
                            Text(trackStats.formattedBpsReceived())
                        }
                    }
                }
            }
            .font(.system(size: 10))
            .foregroundColor(Color.white)
            .padding(5)
            .background(Color.black.opacity(0.5))
            .cornerRadius(8)
        }
    }
}

extension StatsView {

    class DelegateObserver: ObservableObject, TrackDelegate {
        private let track: Track
        @Published var dimensions: Dimensions?
        @Published var stats: TrackStats?

        init(track: Track) {
            self.track = track

            dimensions = track.dimensions
            stats = track.stats

            track.add(delegate: self)
        }

        func track(_ track: VideoTrack, didUpdate dimensions: Dimensions?) {
            Task.detached { @MainActor in
                self.dimensions = dimensions
            }
        }

        func track(_ track: Track, didUpdate stats: TrackStats) {
            Task.detached { @MainActor in
                self.stats = stats
            }
        }
    }
}
