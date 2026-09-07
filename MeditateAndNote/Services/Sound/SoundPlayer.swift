//
//  SoundPlayer.swift
//  MeditateAndNote
//

import AVFoundation

//MARK: - MeditationSound
enum MeditationSound: Equatable {
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

//MARK: - AudioPlayerHandle
/// Narrow view over an audio player: everything `SoundPlayer` needs to
/// orchestrate a replay (volume, seeking, play/prepare) without touching
/// `AVAudioPlayer` directly.
protocol AudioPlayerHandle: AnyObject {
    var volume: Float { get set }
    var currentTime: TimeInterval { get set }
    @discardableResult func play() -> Bool
    @discardableResult func prepareToPlay() -> Bool
}

//MARK: - AudioResourceLoading
/// Resolves a sound resource name to a playable handle. The concrete
/// implementation owns the `Bundle`/`AVFoundation` side effects.
protocol AudioResourceLoading: AnyObject {
    func player(forResource name: String) -> AudioPlayerHandle?
}

//MARK: - SoundPlayer
final class SoundPlayer: SoundPlaying {

    static let shared = SoundPlayer()

    private let soundSettings: SoundSettings
    private let resources: AudioResourceLoading
    private var players: [String: AudioPlayerHandle] = [:]

    init(soundSettings: SoundSettings = .shared,
         resources: AudioResourceLoading = SystemAudioResourceLoader()) {
        self.soundSettings = soundSettings
        self.resources = resources
    }

    func play(_ sound: MeditationSound) {
        guard let player = player(for: sound) else { return }
        player.volume = soundSettings.volume
        player.currentTime = 0
        player.play()
    }

    //MARK: - Private
    private func player(for sound: MeditationSound) -> AudioPlayerHandle? {
        let name = resourceName(for: sound)
        if let cached = players[name] { return cached }
        guard let player = resources.player(forResource: name) else { return nil }
        player.prepareToPlay()
        players[name] = player
        return player
    }

    private func resourceName(for sound: MeditationSound) -> String {
        switch sound {
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

//MARK: - AVAudioPlayer conformance

extension AVAudioPlayer: AudioPlayerHandle {}

//MARK: - SystemAudioResourceLoader
/// Concrete `AudioResourceLoading`: locates bundled sound assets and builds
/// `AVAudioPlayer`s. Owns all `AVFoundation`/`Bundle` side effects so they can
/// be swapped for mocks in tests.
final class SystemAudioResourceLoader: AudioResourceLoading {

    private let resourceExtensions = ["caf", "wav", "m4a"]

    init() {
        configureAudioSession()
    }

    func player(forResource name: String) -> AudioPlayerHandle? {
        guard let url = bundleURL(named: name),
              let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        player.prepareToPlay()
        return player
    }

    //MARK: - Private
    private func configureAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private func bundleURL(named name: String) -> URL? {
        for ext in resourceExtensions {
            if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                return url
            }
        }
        return nil
    }
}
