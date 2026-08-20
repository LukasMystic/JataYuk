//
//  SoundClient.swift
//  JataYuk
//
//  Created by Stanley Pratama Teguh on 29/07/26.
//
import Foundation
import AVFoundation
import UIKit

@MainActor
final class SoundClient: NSObject, AVAudioPlayerDelegate {

    // MARK: - BGM

    private struct TrackFile {
        let filename: String
        let ext: String
        let subdirectory: String?
    }

    private let files: [BGMTrack: TrackFile] = [
        .onboarding: TrackFile(filename: "OnboardingPage", ext: "mp3", subdirectory: "Loading"),
        .main:       TrackFile(filename: "MainPage",       ext: "mp3", subdirectory: nil),
        .experiment: TrackFile(filename: "ProcessBGM",     ext: "mp3", subdirectory: nil),
    ]

    private var playerA: AVAudioPlayer?
    private var playerB: AVAudioPlayer?
    private var activeIsA = true
    private(set) var currentTrack: BGMTrack?
    private var isPaused = false
    private var masterVolume: Float = 1.0
    private var fadeTask: Task<Void, Never>?

    private var activePlayer: AVAudioPlayer? { activeIsA ? playerA : playerB }

    // MARK: - One-shot SFX (non-spatial, overlappable)

    private var activeSFXPlayers: [AVAudioPlayer] = []

    private let oneShotFiles: [SoundEffect: (filename: String, ext: String)] = [
        .buttonPress: (filename: "ButtonPress", ext: "mp3"),
    ]

    // MARK: - Init

    override init() {
        super.init()
        configureAudioSession()
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground),
                                                 name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground),
                                                 name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("SoundClient: failed to configure audio session — \(error)")
        }
    }

    @objc private func appDidEnterBackground() {
        activePlayer?.pause()
    }

    @objc private func appWillEnterForeground() {
        guard !isPaused else { return }
        activePlayer?.play()
    }

    // MARK: - BGM Public API

    func play(_ track: BGMTrack, fadeDuration: TimeInterval = 0.6) async {
        guard track != currentTrack else {
            if isPaused { resume() }
            return
        }
        guard let file = files[track], let url = resolveURL(file) else {
            print("SoundClient: missing asset for \(track)")
            return
        }

        let hadPreviousTrack = currentTrack != nil
        currentTrack = track
        isPaused = false

        do {
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.numberOfLoops = -1
            newPlayer.volume = hadPreviousTrack ? 0 : masterVolume
            newPlayer.prepareToPlay()
            newPlayer.play()

            let oldPlayer = activePlayer
            if activeIsA { playerB = newPlayer } else { playerA = newPlayer }
            activeIsA.toggle()

            fadeTask?.cancel()
            fadeTask = Task { [weak self] in
                await self?.crossfade(from: oldPlayer, to: newPlayer,
                                       duration: hadPreviousTrack ? fadeDuration : 0)
            }
        } catch {
            print("SoundClient: failed to load \(file.filename) — \(error)")
        }
    }

    func pause() {
        guard !isPaused else { return }
        isPaused = true
        activePlayer?.pause()
    }

    func resume() {
        guard isPaused else { return }
        isPaused = false
        activePlayer?.play()
    }

    func stop() {
        fadeTask?.cancel()
        playerA?.stop()
        playerB?.stop()
        playerA = nil
        playerB = nil
        currentTrack = nil
        isPaused = false
    }

    func setVolume(_ volume: Float) {
        masterVolume = max(0, min(1, volume))
        if !isPaused { activePlayer?.volume = masterVolume }
    }

    private func resolveURL(_ file: TrackFile) -> URL? {
        if let sub = file.subdirectory,
           let url = Bundle.main.url(forResource: file.filename, withExtension: file.ext, subdirectory: sub) {
            return url
        }
        return Bundle.main.url(forResource: file.filename, withExtension: file.ext)
    }

    private func crossfade(from oldPlayer: AVAudioPlayer?, to newPlayer: AVAudioPlayer, duration: TimeInterval) async {
        guard duration > 0, let oldPlayer else {
            newPlayer.volume = masterVolume
            oldPlayer?.stop()
            return
        }
        let steps = 20
        let stepNanos = UInt64((duration / Double(steps)) * 1_000_000_000)
        for i in 0...steps {
            if Task.isCancelled { return }
            let progress = Float(i) / Float(steps)
            newPlayer.volume = masterVolume * progress
            oldPlayer.volume = masterVolume * (1 - progress)
            try? await Task.sleep(nanoseconds: stepNanos)
        }
        oldPlayer.stop()
    }

    // MARK: - One-shot SFX Public API

    func playButtonPress() async {
        guard let file = oneShotFiles[.buttonPress] else { return }
        guard let url = Bundle.main.url(forResource: file.filename, withExtension: file.ext) else {
            print("SoundClient: missing SFX asset for buttonPress")
            return
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.volume = masterVolume
            player.numberOfLoops = 0
            player.prepareToPlay()
            player.play()
            activeSFXPlayers.append(player)   // retained until it finishes, so it isn't deallocated mid-playback
        } catch {
            print("SoundClient: failed to play buttonPress SFX — \(error)")
        }
    }

    // MARK: - AVAudioPlayerDelegate

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            self?.activeSFXPlayers.removeAll { $0 === player }
        }
    }
}
