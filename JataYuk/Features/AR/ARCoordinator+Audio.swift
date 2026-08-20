//
//  ARCoordinator+Audio.swift
//  JataYuk
//
//  Spatial SFX (wav/mp3) via RealityKit AudioFileResource anchored to entities.
//  Non-spatial SFX (mov video-container files) via AVPlayer as fallback.
//

import Foundation
import AVFoundation
import RealityKit

extension ARCoordinator {

    // MARK: - Preloading

    func preloadSFX() async {
        // (effect, filename, extension)
        // .wav and .mp3 files get spatial audio via RealityKit AudioFileResource.
        // .mov files (video containers) must use AVPlayer — AudioFileResource rejects them.
        let sfxFiles: [(SoundEffect, String, String)] = [
            (.placeDishSoapOrFoodColoring, "DishSoapFoodColoringPutDown", "mov"),
            (.placeGlass(.sideA),          "glassdownsideA",              "wav"),
            (.placeGlass(.sideB),          "glassdownsideB",              "wav"),
            (.mixOrShake,                  "MixwithSpoon",                "mov"),
            (.pourSand,                    "PourSands",                   "mov"),
            (.pourLiquid,                  "PourWaterNew",                "wav"),
            (.scoopSand,                   "ScoopSand",                   "mov"),
            (.volcanoOutcome,              "VolcanoDUARRRRR",             "mov"),
            (.volcanoPlacement,            "VolcanoPlacementNew",         "mov"),
            (.volcanoReacting,             "VolcanoReact",                "mp3"),
            (.wrongPlacement,              "WrongPlacementNew",           "mov"),
        ]

        // Scene-wide ambient sounds that should play as flat 2D audio.
        // Using RealityKit spatial audio for these applies HRTF that distorts them.
        let nonSpatialEffects: Set<SoundEffect> = [.volcanoReacting, .volcanoOutcome, .volcanoPlacement]

        let spatialConfig = AudioFileResource.Configuration(
            loadingStrategy: .preload,
            shouldLoop: false,
            shouldRandomizeStartTime: false,
            normalization: nil,
            calibration: nil,
            mixGroupName: nil
        )

        for (effect, name, ext) in sfxFiles {
            guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
                print("[Audio] SFX not found in bundle: \(name).\(ext)")
                continue
            }

            if ext == "mov" || nonSpatialEffects.contains(effect) {
                // AVPlayer for video containers and scene-wide ambient sounds.
                sfxAVPlayers[effect] = AVPlayer(url: url)
            } else {
                if let resource = try? await AudioFileResource(contentsOf: url, withName: name, configuration: spatialConfig) {
                    preloadedSFX[effect] = resource
                }
            }
        }
    }

    // MARK: - Playback

    func playSFX(_ effect: SoundEffect, on entity: Entity) {
        if let resource = preloadedSFX[effect] {
            entity.playAudio(resource)
        } else if let player = sfxAVPlayers[effect] {
            // Restart from beginning — necessary if the same sound fires again before it ends.
            player.seek(to: CMTime(seconds: 0, preferredTimescale: 600)) { _ in
                player.play()
            }
        }
    }

    func playPourSFX(for type: BeakerType, entity: Entity?) {
        guard let entity else { return }
        switch type {
        case .yeast:
            playSFX(.pourSand, on: entity)
        default:
            playSFX(.pourLiquid, on: entity)
        }
    }
}
