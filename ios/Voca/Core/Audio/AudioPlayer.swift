import Foundation
import AVFoundation

/// Plays MP3 data returned by the TTS endpoints. One shared player; a new clip replaces the previous.
@MainActor
final class AudioPlayer: NSObject {
    static let shared = AudioPlayer()

    private var player: AVAudioPlayer?
    private var finishContinuation: CheckedContinuation<Void, Never>?

    /// Fire-and-forget playback (single word / one line).
    func play(_ data: Data) {
        prepareSession()
        stop()
        player = try? AVAudioPlayer(data: data)
        player?.prepareToPlay()
        player?.play()
    }

    /// Plays and suspends until playback finishes (or fails) — used for sequential "play all".
    func playAndWait(_ data: Data) async {
        prepareSession()
        stop()
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            do {
                let p = try AVAudioPlayer(data: data)
                p.delegate = self
                player = p
                finishContinuation = cont
                p.prepareToPlay()
                if !p.play() { resumeFinish() }
            } catch {
                cont.resume()
            }
        }
    }

    func stop() {
        player?.stop()
        player = nil
        resumeFinish()
    }

    private func prepareSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private func resumeFinish() {
        finishContinuation?.resume()
        finishContinuation = nil
    }
}

extension AudioPlayer: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.resumeFinish() }
    }
}
