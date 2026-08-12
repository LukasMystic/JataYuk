//
//  FoamChemistry.swift
//  JataYuk
//
//  Created by Teresa Tendeas on 12/08/26.
//

import Foundation
// Chemistry outputs that EmissionSystem + SPHSystem consume.
// Keeps FoamModel as the 5-input ERD field; everything else lives here.
struct FoamChemistryResult: Equatable {
    var peakVolumeL: Double
    var peakHeightCm: Double
    var oxygenL: Double
    var reactionDuration: Double
    var emissionDuration: Double
    var totalParticles: Int
    var stopTime: Double
    var rate: Double
}
enum FoamChemistry {
    static func calculate(from model: FoamModel) -> FoamChemistryResult {
        let rate = yeastFactor(yeast: model.yeastTbsp, tempC: model.tempC)
        let reactionDuration = reactionDuration(
            concentration: model.concentration,
            volumeL: model.volumeL,
            rate: rate
        )
        let peakVolume = volume(
            at: reactionDuration,
            model: model,
            rate: rate,
            reactionDuration: reactionDuration
        )
        let peakHeight = height(
            at: reactionDuration,
            model: model,
            rate: rate,
            reactionDuration: reactionDuration
        )
        let oxygen = oxygenL(concentration: model.concentration, volumeL: model.volumeL)
        let emissionDuration = emissionDuration(for: rate)
        let peakGas = max(0, peakVolume - liquidL(model: model))
        let totalParticles = min(
            ExplosionSandboxConstants.SPH.maxParticles,
            Int(peakGas / ExplosionSandboxConstants.Emitter.litresPerParticle)
        )
        let stop = decayTime(
            model: model,
            rate: rate,
            reactionDuration: reactionDuration,
            peakHeightCm: peakHeight,
            fraction: ExplosionSandboxConstants.Surface.decayFraction
        ) + ExplosionSandboxConstants.Surface.settlePaddingSeconds
        return FoamChemistryResult(
            peakVolumeL: peakVolume,
            peakHeightCm: peakHeight,
            oxygenL: oxygen,
            reactionDuration: reactionDuration,
            emissionDuration: emissionDuration,
            totalParticles: totalParticles,
            stopTime: stop,
            rate: rate
        )
    }
    // MARK: - Rate terms
    static func yeastFactor(yeast: Double, tempC: Double) -> Double {
        let k = ExplosionSandboxConstants.Chemistry.self
        let yeastTerm = k.yeastCeiling * yeast / (yeast + k.yeastHalf)
        return yeastTerm * tempFactor(tempC)
    }
    static func tempFactor(_ tempC: Double) -> Double {
        let floor = ExplosionSandboxConstants.Chemistry.tempFloorFactor
        func formula(_ t: Double) -> Double {
            let q10 = pow(2, (t - 43) / 10)
            let denature = 1.2019 / (1 + exp((t - 47) / 2.5))
            return q10 * denature
        }
        switch tempC {
        case ...20, 50...: return floor
        case ..<25:
            let a = (tempC - 20) / 5
            return floor + (formula(25) - floor) * a
        case ...45:
            return formula(tempC)
        default:
            let a = (tempC - 45) / 5
            return formula(45) + (floor - formula(45)) * a
        }
    }
    // MARK: - Static quantities
    static func oxygenL(concentration: Double, volumeL: Double) -> Double {
        ExplosionSandboxConstants.Chemistry.stoichiometryFactor * concentration * volumeL
    }
    static func capture(soapTbsp: Double) -> Double {
        let k = ExplosionSandboxConstants.Chemistry.self
        return k.soapCeiling * soapTbsp / (soapTbsp + k.soapHalf)
    }
    static func foamHalfLife(soapTbsp: Double) -> Double {
        let k = ExplosionSandboxConstants.Chemistry.self
        return k.halfLifeRef * pow(soapTbsp, k.halfLifeExp)
    }
    static func reactionDuration(concentration: Double, volumeL: Double, rate: Double) -> Double {
        let k = ExplosionSandboxConstants.Chemistry.self
        return k.baseDuration * (concentration / 6) * (volumeL / 0.1) / max(rate, 0.02)
    }
    static func liquidL(model: FoamModel) -> Double {
        model.volumeL
            + ExplosionSandboxConstants.Chemistry.liquidSoapCoeff * model.soapTbsp
            + ExplosionSandboxConstants.Chemistry.liquidBaseL
    }
    static func inflowRate(model: FoamModel, rate: Double, reactionDuration: Double) -> Double {
        oxygenL(concentration: model.concentration, volumeL: model.volumeL)
            * capture(soapTbsp: model.soapTbsp)
            / reactionDuration
    }
    static func emissionDuration(for rate: Double) -> Double {
        let e = ExplosionSandboxConstants.Emitter.self
        return min(
            e.maxEmissionDuration,
            max(e.minEmissionDuration, e.baseEmissionSeconds * e.referenceRate / max(rate, 0.02))
        )
    }
    // MARK: - Time-dependent curves
    static func volume(at t: Double, model: FoamModel, rate: Double, reactionDuration: Double) -> Double {
        guard t > 0 else { return liquidL(model: model) }
        let k = log(2) / foamHalfLife(soapTbsp: model.soapTbsp)
        let ceiling = inflowRate(model: model, rate: rate, reactionDuration: reactionDuration) / k
        let gas: Double
        if t < reactionDuration {
            gas = ceiling * (1 - exp(-k * t))
        } else {
            let peak = ceiling * (1 - exp(-k * reactionDuration))
            gas = peak * exp(-k * (t - reactionDuration))
        }
        return gas + liquidL(model: model)
    }
    static func height(at t: Double, model: FoamModel, rate: Double, reactionDuration: Double) -> Double {
        let area = Double.pi * model.containerRadiusCm * model.containerRadiusCm
        let vCm3 = volume(at: t, model: model, rate: rate, reactionDuration: reactionDuration) * 1000
        let contCm3 = model.containerVolumeL * 1000
        let contained = min(vCm3, contCm3) / area
        let excess = max(0, vCm3 - contCm3)
        guard excess > 0 else { return contained }
        let pile = pow(
            3 * ExplosionSandboxConstants.Chemistry.pileAspect
                * ExplosionSandboxConstants.Chemistry.pileAspect
                * excess / Double.pi,
            1.0 / 3.0
        )
        let momentum = (rate / ExplosionSandboxConstants.Chemistry.rateRef).squareRoot()
        return contained + pile * momentum
    }
    static func decayTime(
        model: FoamModel,
        rate: Double,
        reactionDuration: Double,
        peakHeightCm: Double,
        fraction: Double
    ) -> Double {
        let target = peakHeightCm * fraction
        var t = reactionDuration
        while t < 600 && height(at: t, model: model, rate: rate, reactionDuration: reactionDuration) > target {
            t += 0.5
        }
        return t
    }
    // Per-frame force drivers for SPHComponent
    static func frameForces(
        elapsed: Double,
        emissionDuration: Double,
        peakHeightCm: Double,
        rate: Double,
        baseViscosity: Float,
        baseCohesion: Float
    ) -> (gasLift: Float, liftCeiling: Float, viscosity: Float, cohesion: Float) {
        let sph = ExplosionSandboxConstants.SPH.self
        let container = ExplosionSandboxConstants.Container.self
        if elapsed < emissionDuration {
            let vigor = Float(min(Double(sph.vigorCap), rate / sph.referenceModelRate))
            let gasLift = sph.gasLiftBase + sph.gasLiftScale * vigor
            let plume = Float(peakHeightCm / 100.0)
            let liftCeiling = max(container.height + sph.rimOverflowPadding, plume)
            return (gasLift, liftCeiling, baseViscosity, baseCohesion)
        }
        let relaxSpan = sph.rheologyRelaxSpan
        let k = Float(max(0, min(1, (elapsed - emissionDuration) / relaxSpan)))
        return (
            0,
            0,
            baseViscosity * (1 - sph.rheologyViscosityFade * k),
            baseCohesion * (1 - sph.rheologyCohesionFade * k)
        )
    }
}
