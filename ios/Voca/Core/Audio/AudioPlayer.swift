import Foundation
import AVFoundation

/// Plays MP3 data returned by the TTS endpoints. One shared player; a new clip replaces the previous.
@MainActor
final class AudioPlayer: NSObject {
    static let shared = AudioPlayer()

    private var player: AVAudioPlayer?

    func play(_ data: Data) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(data: data)
            player?.prepareToPlay()
            player?.play()
        } catch {
            print("[AudioPlayer] playback error: \(error)")
        }
    }

    func stop() {
        player?.stop()
        player = nil
    }
}
