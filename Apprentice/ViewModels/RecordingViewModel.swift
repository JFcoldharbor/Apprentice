//
//  RecordingViewModel.swift
//  Apprentice
//
//  Layer 4 (ViewModels) — drives the recording screen's state machine and
//  forwards live engine/transcriber state to the view. Wraps NoteCaptureService
//  (L3); the view never touches the services or the store directly.
//

import Foundation
import SwiftUI
import SwiftData
import Combine
import AVFoundation

@MainActor
final class RecordingViewModel: ObservableObject {

    enum Phase: Equatable {
        case idle
        case recording
        case paused
    }

    @Published private(set) var phase: Phase = .idle
    @Published var pendingTitle: String = ""
    @Published var noteType: NoteType = .general
    @Published var pendingAttendees: [String] = []
    @Published var errorMessage: String?
    @Published private(set) var micDenied = false

    let capture: NoteCaptureService
    private var cancellables = Set<AnyCancellable>()

    init(context: ModelContext) {
        capture = NoteCaptureService(context: context)

        // Republish nested ObservableObject changes so the view updates on
        // elapsed/level/live-transcript ticks.
        capture.objectWillChange
            .merge(with: capture.engine.objectWillChange)
            .merge(with: capture.live.objectWillChange)
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    // MARK: - Forwarded live state

    var elapsed: TimeInterval { capture.engine.elapsed }
    var audioLevel: Float { capture.engine.audioLevel }
    var chunkCount: Int { (capture.currentNote?.chunks.count ?? 0) }
    var liveTranscript: String { capture.live.transcript }
    var isLiveAvailable: Bool { capture.live.isAvailable }
    var currentNote: Note? { capture.currentNote }

    var formattedElapsed: String {
        let total = Int(elapsed)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    var isActive: Bool { phase != .idle }

    // MARK: - Permissions

    func requestPermissions() async {
        let micGranted = await Self.requestMicPermission()
        await MainActor.run { self.micDenied = !micGranted }
        _ = await LiveTranscriber.requestAuthorization()
    }

    private static func requestMicPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    // MARK: - Transport

    func start() {
        errorMessage = nil
        do {
            try capture.startRecording(type: noteType, title: pendingTitle, attendees: pendingAttendees)
            phase = .recording
        } catch {
            errorMessage = error.localizedDescription
            phase = .idle
        }
    }

    func pause() {
        capture.pause()
        phase = .paused
    }

    func resume() {
        capture.resume()
        phase = .recording
    }

    /// Stop and finalize. Returns the completed note so the view can navigate to it.
    @discardableResult
    func stop() -> Note? {
        let note = capture.currentNote
        capture.stopRecording()
        phase = .idle
        pendingTitle = ""
        noteType = .general
        pendingAttendees = []
        return note
    }
}
