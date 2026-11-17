import Foundation
import AVFoundation

/// Tự động tải trước (preload) hội thoại và âm thanh để phát liên tục.
class AudioPreloader {
    static let shared = AudioPreloader()
    
    // Tạm thời chỉ lưu URL hoặc data để phát.
    private var cache = NSCache<NSString, NSData>()
    
    func preload(conversation: Conversation) async {
        // Logica tải trước TTS cho các dòng của hội thoại
        for line in conversation.lines {
            guard let text = line.text, !text.isEmpty else { continue }
            // Tương tự như cơ chế trong bản cũ: dùng TTSService để lấy audio
            // và lưu vào cache hoặc disk.
        }
    }
}
