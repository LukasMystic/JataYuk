//
//  SPHCompute.metal
//  JataYuk
//
//  GPU port of the SPH solver. Each particle is one GPU thread. Neighbour search
//  is brute-force O(n²) — fine for ≤500 particles and avoids a GPU spatial hash.
//  Two kernels per substep: density/pressure, then forces + integration + collisions.
//  Physics matches SPHSolver.swift (gas lift, apex spread, yield/stacking, walls).
//

#include <metal_stdlib>
using namespace metal;

// MUST match the Swift `Uniforms` struct in GPUSPHSolver.swift field-for-field
// (all 4-byte scalars, same order).
struct Uniforms {
    uint  count;
    float dt;
    float h;
    float h2;
    float poly6;
    float spikyGrad;
    float viscLap;
    float mass;
    float restDensity;
    float stiffness;
    float viscosity;          // runtime (may be lowered over time)
    float cohesion;           // runtime
    float xsph;
    float gravityY;
    float damping;
    float restitution;
    float friction;
    float maxSpeed;
    float collisionRadius;
    float yieldSpeed;
    float restFriction;
    float restAccel;
    float stackRadius;
    float gasLift;
    float liftCeiling;
    float topSpread;
    float apexSpeed;
    float rimHeight;
    float cylRadius;
    float floorContactBand;
    float floorContactDamping;
    uint  seed;
};

// --- Small hash RNG (PCG-style) for the apex-spread jitter ---
inline uint pcg(uint v) {
    uint state = v * 747796405u + 2891336453u;
    uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
    return (word >> 22u) ^ word;
}
inline float nextRand(thread uint &s) {
    s = pcg(s);
    return float(s) * (1.0 / 4294967296.0);   // [0,1)
}

// --- Boundary handling (mirrors resolveCollisions / reflectRadial in Swift) ---
inline void reflectRadial(thread float3 &v, float2 dir, constant Uniforms &u) {
    float vr = v.x * dir.x + v.z * dir.y;
    v.x -= (1.0 + u.restitution) * vr * dir.x;
    v.z -= (1.0 + u.restitution) * vr * dir.y;
    v.y *= (1.0 - u.friction * 0.5);
}

inline void resolveCollisions(thread float3 &p, thread float3 &v, constant Uniforms &u) {
    float r = u.collisionRadius;

    // Floor + contact band that soaks up the pressure bounce.
    if (p.y < r) {
        p.y = r;
        if (v.y < 0.0) v.y = -v.y * u.restitution;
        v.x *= (1.0 - u.friction);
        v.z *= (1.0 - u.friction);
    } else if (p.y < r + u.floorContactBand) {
        v.y *= u.floorContactDamping;
    }

    // Cylinder wall (only below the rim). Keeps a particle on whichever side it's on.
    if (p.y < u.rimHeight) {
        float radial = sqrt(p.x * p.x + p.z * p.z);
        if (radial > 1e-6) {
            float2 dir = float2(p.x, p.z) / radial;
            if (radial < u.cylRadius) {                 // inside
                float maxR = u.cylRadius - r;
                if (radial > maxR) { p.x = dir.x * maxR; p.z = dir.y * maxR; reflectRadial(v, dir, u); }
            } else {                                     // outside
                float minR = u.cylRadius + r;
                if (radial < minR) { p.x = dir.x * minR; p.z = dir.y * minR; reflectRadial(v, dir, u); }
            }
        }
    }
}

// --- Kernel 1: density + pressure ---
kernel void sphDensity(device const float3 *positions  [[buffer(0)]],
                       device const float3 *velocities [[buffer(1)]],
                       device float *densities         [[buffer(2)]],
                       device float *pressures         [[buffer(3)]],
                       constant Uniforms &u            [[buffer(4)]],
                       uint i [[thread_position_in_grid]]) {
    if (i >= u.count) return;
    float3 pi = positions[i];
    float density = u.mass * u.poly6 * (u.h2 * u.h2 * u.h2);   // self-contribution
    for (uint j = 0; j < u.count; ++j) {
        if (j == i) continue;
        float3 d = pi - positions[j];
        float r2 = dot(d, d);
        if (r2 < u.h2) {
            float x = u.h2 - r2;
            density += u.mass * u.poly6 * x * x * x;
        }
    }
    densities[i] = density;
    pressures[i] = max(0.0, u.stiffness * (density - u.restDensity));
}

// --- Kernel 2: forces + gas lift + apex spread + integrate + collisions ---
kernel void sphForcesIntegrate(device float3 *positions       [[buffer(0)]],
                               device float3 *velocities      [[buffer(1)]],
                               device const float *densities  [[buffer(2)]],
                               device const float *pressures  [[buffer(3)]],
                               constant Uniforms &u           [[buffer(4)]],
                               uint i [[thread_position_in_grid]]) {
    if (i >= u.count) return;
    float3 pi = positions[i];
    float3 vi = velocities[i];
    float pressI = pressures[i];

    float3 fP = float3(0.0);   // pressure
    float3 fV = float3(0.0);   // viscosity
    float3 fC = float3(0.0);   // cohesion
    float3 xsphDelta = float3(0.0);

    for (uint j = 0; j < u.count; ++j) {
        if (j == i) continue;
        float3 rvec = pi - positions[j];
        float r2 = dot(rvec, rvec);
        if (r2 >= u.h2 || r2 <= 1e-12) continue;
        float r = sqrt(r2);
        float densJ = densities[j];
        if (densJ <= 0.0) continue;

        float3 grad = u.spikyGrad * (u.h - r) * (u.h - r) * (rvec / r);
        float shared = (pressI + pressures[j]) / (2.0 * densJ);
        fP += -u.mass * shared * grad;

        float lap = u.viscLap * (u.h - r);
        fV += u.viscosity * u.mass * (velocities[j] - vi) / densJ * lap;

        float x = u.h2 - r2;
        float w = u.poly6 * x * x * x;
        fC += -u.cohesion * u.mass * rvec * w;

        xsphDelta += (u.mass / densJ) * (velocities[j] - vi) * w;
    }

    float densI = max(densities[i], 1e-5);
    float3 a = (fP + fV + fC) / densI;
    a.y += u.gravityY;

    // Gas lift (tapered) inside the vessel.
    if (u.gasLift != 0.0 && pi.y < u.liftCeiling &&
        (pi.x * pi.x + pi.z * pi.z) < u.cylRadius * u.cylRadius) {
        float span = max(u.liftCeiling - u.rimHeight, 1e-4);
        float frac = min(1.0, (u.liftCeiling - pi.y) / span);
        a.y += u.gasLift * frac;
    }

    // Apex spread: fan sideways near the top of the arc.
    if (u.topSpread > 0.0 && pi.y > u.rimHeight) {
        float vy = vi.y;
        if (vy < u.apexSpeed) {
            float f = max(0.0, 1.0 - fabs(vy) / u.apexSpeed);
            uint s = pcg(i + u.seed);
            float radial = sqrt(pi.x * pi.x + pi.z * pi.z);
            float ox, oz;
            if (radial > 1e-4) { ox = pi.x / radial; oz = pi.z / radial; }
            else { float ang = nextRand(s) * 6.2831853; ox = cos(ang); oz = sin(ang); }
            float jAng = nextRand(s) * 6.2831853;
            float mix = 0.6;
            float mag = u.topSpread * f * nextRand(s);
            a.x += (ox * mix + cos(jAng) * (1.0 - mix)) * mag;
            a.z += (oz * mix + sin(jAng) * (1.0 - mix)) * mag;
        }
    }

    // Semi-implicit Euler + XSPH + damping + speed clamp.
    float damp = max(0.0, 1.0 - u.damping * u.dt);
    float3 v = vi + a * u.dt;
    v += u.xsph * xsphDelta;
    v *= damp;

    float speed = length(v);
    if (speed > u.maxSpeed) v *= u.maxSpeed / speed;

    // Yield / static friction with radial stacking bias.
    float stackRadial = sqrt(pi.x * pi.x + pi.z * pi.z);
    float nearBeaker = max(0.0, 1.0 - stackRadial / u.stackRadius);
    float yieldHere = u.yieldSpeed * (0.3 + 0.7 * nearBeaker);
    if (speed < yieldHere && length(a) < u.restAccel) {
        v *= u.restFriction;
    }

    float3 p = pi + v * u.dt;
    resolveCollisions(p, v, u);

    positions[i] = p;
    velocities[i] = v;
}
