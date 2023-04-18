import SwiftUI
import LiveKit
import WebRTC
import Combine

// This class contains the logic to control behavior of the whole app.
final class RoomContext: ObservableObject {

    let jsonEncoder = JSONEncoder()
    let jsonDecoder = JSONDecoder()

    private let store: ValueStore<Preferences>

    // Used to show connection error dialog
    // private var didClose: Bool = false
    @Published var shouldShowDisconnectReason: Bool = false
    public var latestError: DisconnectReason?

    @Published var showMessagesView: Bool = false
    @Published var messages: [ExampleRoomMessage] = []
    @Published var focusParticipant: Participant?
    @Published var textFieldString: String = ""

    @Published public var cameraTrackState: TrackPublishState = .notPublished()
    @Published public var microphoneTrackState: TrackPublishState = .notPublished()
    @Published public var screenShareTrackState: TrackPublishState = .notPublished()

    // @ObservedObject
    public var room = Room()

    @Published var url: String = "" {
        didSet { store.value.url = url }
    }

    @Published var token: String = "" {
        didSet { store.value.token = token }
    }

    // RoomOptions
    @Published var simulcast: Bool = true {
        didSet { store.value.simulcast = simulcast }
    }

    @Published var adaptiveStream: Bool = false {
        didSet { store.value.adaptiveStream = adaptiveStream }
    }

    @Published var dynacast: Bool = false {
        didSet { store.value.dynacast = dynacast }
    }

    @Published var reportStats: Bool = false {
        didSet { store.value.reportStats = reportStats }
    }

    // ConnectOptions
    @Published var autoSubscribe: Bool = true {
        didSet { store.value.autoSubscribe = autoSubscribe}
    }

    @Published var publish: Bool = false {
        didSet { store.value.publishMode = publish }
    }

    private var roomSubscription: AnyCancellable?

    public init(store: ValueStore<Preferences>) {
        self.store = store
        room.add(delegate: self)

        self.url = store.value.url
        self.token = store.value.token
        self.simulcast = store.value.simulcast
        self.adaptiveStream = store.value.adaptiveStream
        self.dynacast = store.value.dynacast
        self.reportStats = store.value.reportStats
        self.autoSubscribe = store.value.autoSubscribe
        self.publish = store.value.publishMode

        #if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = true
        #endif

        roomSubscription = room.objectWillChange.sink(receiveValue: objectWillChange.send)
    }

    deinit {
        #if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = false
        #endif
        print("RoomContext.deinit")
    }

    @MainActor
    func connect(entry: ConnectionHistory? = nil) async throws -> Room {

        if let entry = entry {
            url = entry.url
            token = entry.token
        }

        let connectOptions = ConnectOptions(
            autoSubscribe: !publish && autoSubscribe, // don't autosubscribe if publish mode
            publishOnlyMode: publish ? "publish_\(UUID().uuidString)" : nil
        )

        let roomOptions = RoomOptions(
            defaultCameraCaptureOptions: CameraCaptureOptions(
                dimensions: .h1080_169
            ),
            defaultScreenShareCaptureOptions: ScreenShareCaptureOptions(
                dimensions: .h1080_169,
                useBroadcastExtension: true
            ),
            defaultVideoPublishOptions: VideoPublishOptions(
                simulcast: publish ? false : simulcast
            ),
            adaptiveStream: adaptiveStream,
            dynacast: dynacast,
            reportStats: reportStats
        )

        return try await room.connect(url,
                                      token,
                                      connectOptions: connectOptions,
                                      roomOptions: roomOptions)
    }

    func disconnect() async throws {
        try await room.disconnect()
    }

    @MainActor
    func unpublishAll() async throws {
        guard let localParticipant = self.room.localParticipant else { return }
        try await localParticipant.unpublishAll()
        cameraTrackState = .notPublished()
        microphoneTrackState = .notPublished()
        screenShareTrackState = .notPublished()
    }

    @MainActor
    func sendMessage() {

        guard let localParticipant = room.localParticipant else {
            print("LocalParticipant doesn't exist")
            return
        }

        // Make sure the message is not empty
        guard !textFieldString.isEmpty else { return }

        let roomMessage = ExampleRoomMessage(messageId: UUID().uuidString,
                                             senderSid: localParticipant.sid,
                                             senderIdentity: localParticipant.identity,
                                             text: textFieldString)
        textFieldString = ""
        messages.append(roomMessage)

        do {
            let json = try jsonEncoder.encode(roomMessage)

            localParticipant.publishData(data: json).then {
                print("did send data")
            }.catch { error in
                print("failed to send data \(error)")
            }

        } catch let error {
            print("Failed to encode data \(error)")
        }
    }

    @MainActor
    public func switchCameraPosition() async throws {

        guard case .published(let publication) = self.cameraTrackState,
              let track = publication.track as? LocalVideoTrack,
              let cameraCapturer = track.capturer as? CameraCapturer else {
            throw TrackError.state(message: "Track or a CameraCapturer doesn't exist")
        }

        try await cameraCapturer.switchCameraPosition()
    }

    @MainActor
    public func toggleCameraEnabled() async throws {

        guard let localParticipant = room.localParticipant else { return }
        guard !cameraTrackState.isBusy else { return }

        cameraTrackState = .busy(isPublishing: !cameraTrackState.isPublished)

        do {
            let publication = try await localParticipant.setCamera(enabled: !localParticipant.isCameraEnabled())
            guard let publication = publication else { return }
            cameraTrackState = .published(publication)
        } catch let error {
            cameraTrackState = .notPublished(error: error)
        }
    }

    @MainActor
    public func toggleMicrophoneEnabled() async throws {

        guard let localParticipant = room.localParticipant else { return }
        guard !microphoneTrackState.isBusy else { return }

        microphoneTrackState = .busy(isPublishing: !microphoneTrackState.isPublished)

        do {
            let publication = try await localParticipant.setMicrophone(enabled: !localParticipant.isMicrophoneEnabled())
            guard let publication = publication else { return }
            microphoneTrackState = .published(publication)
        } catch let error {
            microphoneTrackState = .notPublished(error: error)
        }
    }

    @MainActor
    public func toggleScreenShareEnabled() async throws {

        guard let localParticipant = room.localParticipant else { return }
        guard !screenShareTrackState.isBusy else { return }

        screenShareTrackState = .busy(isPublishing: !screenShareTrackState.isPublished)

        do {
            let publication = try await localParticipant.setScreenShare(enabled: !localParticipant.isScreenShareEnabled())
            guard let publication = publication else { return }
            self.screenShareTrackState = .published(publication)
        } catch let error {
            screenShareTrackState = .notPublished(error: error)
        }
    }

    #if os(macOS)
    @MainActor
    func toggleScreenShareEnabledMacOS(screenShareSource: MacOSScreenCaptureSource? = nil) async throws {

        guard let localParticipant = room.localParticipant else { return }
        guard !screenShareTrackState.isBusy else { return }

        if case .published(let track) = screenShareTrackState {

            screenShareTrackState = .busy(isPublishing: false)

            try await localParticipant.unpublish(publication: track)
            screenShareTrackState = .notPublished()
        } else {

            guard let source = screenShareSource else { return }

            screenShareTrackState = .busy(isPublishing: true)

            do {
                let track = LocalVideoTrack.createMacOSScreenShareTrack(source: source)
                let publication = try await localParticipant.publishVideo(track)
                screenShareTrackState = .published(publication)

            } catch let error {
                screenShareTrackState = .notPublished(error: error)
            }
        }
    }
    #endif
}

extension RoomContext: RoomDelegate {

    func room(_ room: Room, didUpdate connectionState: ConnectionState, oldValue: ConnectionState) {

        print("Did update connectionState \(oldValue) -> \(connectionState)")

        if case .disconnected(let reason) = connectionState, reason != .user {
            latestError = reason
            DispatchQueue.main.async {
                self.shouldShowDisconnectReason = true
            }
        }

        DispatchQueue.main.async {
            withAnimation {
                self.objectWillChange.send()
            }
        }
    }
}
