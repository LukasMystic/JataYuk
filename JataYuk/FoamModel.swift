//
//  FoamModel.swift
//  JataYuk
//
//  Created by Teresa Tendeas on 06/08/26.
//

import Foundation
// Volume and height are functions of time. Everything is driven by five inputs;
//   • call `volume(at:)` / `height(at:)` each frame with elapsed seconds.
//   • Units matter: `volumeL` is LITRES (0.1 = 100 mL), `concentration` is a plainpercent (6.0 = 6% w/v, not 0.06).

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
    // Michaelis–Menten. Plateaus, never declines.
    var yeastFactor: Double {
        yeastCeiling * yeastTbsp / (yeastTbsp + yeastHalf)
    }
    // Temperature response, shaped so the extremes barely react and the transitions near them are sharp:
    //   • 20 °C and 50 °C → "very little" (a small floor)
    //   • 20→25 °C → linear ramp up from the floor to the formula value at 25
    //   • 25→45 °C → the original Q10 × denaturation formula (peaks ~43 °C)
    //   • 45→50 °C → linear ramp down from the formula value at 45 to the floor
    var tempFactor: Double {
        let floorFactor = 0.05   // "very little" at 20 °C and 50 °C
        
        // Original Q10 doubling × denaturation sigmoid (peaks ~43 °C, ≈1.0).
        func formula(_ t: Double) -> Double {
            let q10 = pow(2, (t - 43) / 10)
            let denature = 1.2019 / (1 + exp((t - 47) / 2.5))
            return q10 * denature
        }
        
        let T = tempC
        if T <= 20 || T >= 50 {
            return floorFactor
        } else if T < 25 {
            let a = (T - 20) / 5                       // 0 at 20 → 1 at 25
            return floorFactor + (formula(25) - floorFactor) * a
        } else if T <= 45 {
            return formula(T)                          // core: original formula
        } else {
            let a = (T - 45) / 5                       // 0 at 45 → 1 at 50
            return formula(45) + (floorFactor - formula(45)) * a
        }
    }
    // Combined rate multiplier.
    var rate: Double { yeastFactor * tempFactor }
    
    // MARK: - Static quantities
    var oxygenL: Double { 3.59 * concentration * volumeL } // Total O2 from stoichiometry.
    var capture: Double { soapCeiling * soapTbsp / (soapTbsp + soapHalf) } // Fraction of gas the soap film can trap.
    var foamHalfLife: Double { halfLifeRef * pow(soapTbsp, halfLifeExp) } // Foam half-life, seconds.
    var collapseK: Double { log(2) / foamHalfLife } // First-order collapse constant, per second.
    var reactionDuration: Double {baseDuration * (concentration / 6) * (volumeL / 0.1) / max(rate, 0.02)}
    var liquidL: Double { volumeL + 0.015 * soapTbsp + 0.045 } // Liquid that pools.
    var inflowRate: Double { oxygenL * capture / reactionDuration } // Constant gas inflow during the reaction, L/s.
    
    // MARK: - Time-dependent
    // Foam volume in litres at `t` seconds after pouring.
    //   • Rise: dV/dt = Qin - kV, integrated from zero.
    //   • Collapse: pure exponential decay once the peroxide runs out.
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
    // Foam height in cm at `t` seconds.
    //   • Two regimes. Inside the container height is linear in volume (walls prevent spreading).
    //   • Above the rim the foam piles at its own repose angle, so the excess contributes as a cube root.
    //   • Momentum multiplies only the plume — confined foam cannot be thrown taller.
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
    // Peak occurs exactly when the peroxide runs out.
    var peakTime: Double { reactionDuration }
    var peakVolumeL: Double { volume(at: peakTime) }
    var peakHeightCm: Double { height(at: peakTime) }
    
    // Fraction of produced gas still alive as foam at the peak.
    // Slow reactions lose more — same gas, less of it at once.
    var captureAtPeak: Double {
        let x = collapseK * reactionDuration
        return (1 - exp(-x)) / x
    }
    // Total gas produced so far, litres. Reaches `oxygenL` and stops.
    // Show this next to the animation: two runs, different plumes, same total.
    func gasProduced(upTo t: Double) -> Double {
        oxygenL * min(1, max(0, t / reactionDuration))
    }
}

// MARK: - Rendering helper
extension FoamModel {
    // Sample the curve. Useful for charts, or for baking a keyframe track.
    func samples(until seconds: Double, step: Double = 1.0/60.0) -> [(t: Double, volumeL: Double, heightCm: Double)] {
        stride(from: 0, through: seconds, by: step).map {
            (t: $0, volumeL: volume(at: $0), heightCm: height(at: $0))
        }
    }
    // Point at which the foam is no longer visually interesting.
    // Height has decayed to `fraction` of peak.
    func decayTime(to fraction: Double = 0.25) -> Double {
        let target = peakHeightCm * fraction
        var t = peakTime
        while t < 600 && height(at: t) > target { t += 0.5 }
        return t
    }
}
