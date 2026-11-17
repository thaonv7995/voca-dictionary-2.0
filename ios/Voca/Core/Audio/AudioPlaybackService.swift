import AVFoundation
import Foundation

class AudioPlaybackService: NSObject {
    static let shared = AudioPlaybackService()
    
    private var player: AVQueuePlayer?
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.duckOthers, .mixWithOthers])
            try session.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    func play(urls: [URL]) {
        let playerItems = urls.map { AVPlayerItem(url: $0) }
        player = AVQueuePlayer(items: playerItems)
        player?.play()
    }
    
    func stop() {
        player?.pause()
        player?.removeAllItems()
    }
    
    func pause() {
        player?.pause()
    }
    
    func resume() {
        player?.play()
    }
}
