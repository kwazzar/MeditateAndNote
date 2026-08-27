//
//  SoundPlayer.swift
//  MeditateAndNote
//

import AVFoundation

//MARK: - MeditationSound
enum MeditationSound {
    case started
    case paused
    case resumed
    case finished
    case countdownTick
    case phase(BreathingPhaseType)
}

//MARK: - SoundPlaying
protocol SoundPlaying: AnyObject {
    func play(_ sound: MeditationSound)
}

//MARK: - SoundPlayer
final class SoundPlayer: SoundPlaying {

    static let shared = SoundPlayer()

    private var players: [String: AVAudioPlayer] = [:]
    private let resourceExtensions = ["caf", "wav", "m4a"]

    private init() {
        configureAudioSession()
    }

    func play(_ sound: MeditationSound) {
        guard let player = player(for: sound) else { return }
        player.currentTime = 0
        player.play()
    }

    //MARK: - Private
    private func configureAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private func player(for sound: MeditationSound) -> AVAudioPlayer? {
        let name = resourceName(for: sound)
        if let cached = players[name] { return cached }
        guard let url = bundleURL(named: name),
              let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        player.prepareToPlay()
        players[name] = player
        return player
    }

    private func bundleURL(named name: String) -> URL? {
        for ext in resourceExtensions {
            if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                return url
            }
        }
        return nil
    }

    private func resourceName(for sound: MeditationSound) -> String {
        switch sound {
        case .started: return "meditation_started"
        case .paused: return "meditation_paused"
        case .resumed: return "meditation_resumed"
        case .finished: return "meditation_finished"
        case .countdownTick: return "meditation_countdown"
        case .phase(let type):
            switch type {
            case .inhale: return "breath_inhale"
            case .holdAfterInhale: return "breath_hold"
            case .exhale: return "breath_exhale"
            case .holdAfterExhale: return "breath_hold"
            }
        }
    }
}
