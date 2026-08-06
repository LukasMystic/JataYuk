//
//  FoamModel.swift
//  JataYuk
//
//  Created by Teresa Tendeas on 06/08/26.
//

import Foundation
/// Elephant toothpaste simulation.
///
/// Volume and height are functions of time. Everything is driven by five inputs;
/// call `volume(at:)` / `height(at:)` each frame with elapsed seconds.
///
/// Units matter: `volumeL` is LITRES (0.1 = 100 mL), `concentration` is a plain
/// percent (6.0 = 6% w/v, not 0.06).
struct FoamModel {
    // MARK: - Inputs
    var concentration: Double = 6.0     // % w/v      3...9
    var volumeL: Double       = 0.1     // litres     0.1...0.3
    var soapTbsp: Double      = 1.0     // tbsp       0.5...3
    var yeastTbsp: Double     = 1.0     // tbsp       0.5...4
    var tempC: Double         = 30.0    // °C         20...50
    // MARK: - Container geometry
    var containerRadiusCm: Double = 3.5
    var containerVolumeL: Double  = 0.5
    // MARK: - Calibration
    // Anchored so 6%, 100 mL, 1 tbsp, 1 tbsp, 25 °C gives 30 cm.
    // Every constant here is fitted, not measured. Retune against a real run.
    private let rateRef      = 0.345    // R at the 25 °C calibration point
    private let pileAspect   = 2.34     // plume height / base radius
    private let soapCeiling  = 0.85     // max gas capture fraction
    private let soapHalf     = 0.21     // tbsp at half capture
    private let yeastHalf    = 0.8      // tbsp at half rate
    private let yeastCeiling = 1.8
    private let halfLifeRef  = 40.0     // foam half-life at 1 tbsp soap, seconds
    private let halfLifeExp  = 0.45
    private let baseDuration = 6.9      // seconds at 6%, 100 mL, R = 1
    // MARK: - Rate terms
    /// Michaelis–Menten. Plateaus, never declines.
    var yeastFactor: Double {
        yeastCeiling * yeastTbsp / (yeastTbsp + yeastHalf)
    }
    /// Q10 doubling times a denaturation sigmoid. Peaks at 43.1 °C.
    var tempFactor: Double {
        let q10 = pow(2, (tempC - 43) / 10)
        let denature = 1.2019 / (1 + exp((tempC - 47) / 2.5))
        return q10 * denature
    }
    /// Combined rate multiplier.
    var rate: Double { yeastFactor * tempFactor }
    // MARK: - Static quantities
    /// Total O2 from stoichiometry. Independent of everything except C and V.
    var oxygenL: Double { 3.59 * concentration * volumeL }
    /// Fraction of gas the soap film can trap. Saturates above the CMC.
    var capture: Double { soapCeiling * soapTbsp / (soapTbsp + soapHalf) }
    /// Foam half-life, seconds. Drainage, not rupture, is the slow step.
    var foamHalfLife: Double { halfLifeRef * pow(soapTbsp, halfLifeExp) }
    /// First-order collapse constant, per second.
    var collapseK: Double { log(2) / foamHalfLife }
    /// How long gas is produced. Near zero-order, so C and V scale it linearly.
    var reactionDuration: Double {
        baseDuration * (concentration / 6) * (volumeL / 0.1) / max(rate, 0.02)
    }
    /// Liquid that pools and does not drain away, litres.
    var liquidL: Double { volumeL + 0.015 * soapTbsp + 0.045 }
    /// Constant gas inflow during the reaction, L/s.
    var inflowRate: Double { oxygenL * capture / reactionDuration }
    // MARK: - Time-dependent
    /// Foam volume in litres at `t` seconds after pouring.
    ///
    /// Rise:     dV/dt = Qin - kV, integrated from zero.
    /// Collapse: pure exponential decay once the peroxide runs out.
    func volume(at t: Double) -> Double {
        guard t > 0 else { return liquidL }
        let k = collapseK
        let tRxn = reactionDuration
        let ceiling = inflowRate / k
        let gas: Double
        if t < tRxn {
            gas = ceiling * (1 - exp(-k * t))
        } else {
            let peak = ceiling * (1 - exp(-k * tRxn))
            gas = peak * exp(-k * (t - tRxn))
        }
        return gas + liquidL
    }
    /// Foam height in cm at `t` seconds.
    ///
    /// Two regimes. Inside the container height is linear in volume (walls
    /// prevent spreading). Above the rim the foam piles at its own repose
    /// angle, so the excess contributes as a cube root. Momentum multiplies
    /// only the plume — confined foam cannot be thrown taller.
    func height(at t: Double) -> Double {
        let area = Double.pi * containerRadiusCm * containerRadiusCm
        let vCm3 = volume(at: t) * 1000
        let contCm3 = containerVolumeL * 1000
        let contained = min(vCm3, contCm3) / area
        let excess = max(0, vCm3 - contCm3)
        guard excess > 0 else { return contained }
        let pile = pow(3 * pileAspect * pileAspect * excess / Double.pi, 1.0 / 3.0)
        let momentum = (rate / rateRef).squareRoot()
        return contained + pile * momentum
    }
    // MARK: - Peaks
    /// Peak occurs exactly when the peroxide runs out.
    var peakTime: Double { reactionDuration }
    var peakVolumeL: Double { volume(at: peakTime) }
    var peakHeightCm: Double { height(at: peakTime) }
    /// Fraction of produced gas still alive as foam at the peak.
    /// Slow reactions lose more — same gas, less of it at once.
    var captureAtPeak: Double {
        let x = collapseK * reactionDuration
        return (1 - exp(-x)) / x
    }
    /// Total gas produced so far, litres. Reaches `oxygenL` and stops.
    /// Show this next to the animation: two runs, different plumes, same total.
    func gasProduced(upTo t: Double) -> Double {
        oxygenL * min(1, max(0, t / reactionDuration))
    }
}
// MARK: - Rendering helper
extension FoamModel {
    /// Sample the curve. Useful for charts, or for baking a keyframe track.
    func samples(until seconds: Double, step: Double = 1.0/60.0) -> [(t: Double, volumeL: Double, heightCm: Double)] {
        stride(from: 0, through: seconds, by: step).map {
            (t: $0, volumeL: volume(at: $0), heightCm: height(at: $0))
        }
    }
    /// Point at which the foam is no longer visually interesting.
    /// Height has decayed to `fraction` of peak.
    func decayTime(to fraction: Double = 0.25) -> Double {
        let target = peakHeightCm * fraction
        var t = peakTime
        while t < 600 && height(at: t) > target { t += 0.5 }
        return t
    }
}
