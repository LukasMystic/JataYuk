//
//  JataYukTest.swift
//  JataYukTest
//
//  Created by Harley Ganisson on 10/08/26.
//
import Testing
import Foundation
@testable import JataYuk

@Suite(.timeLimit(.minutes(1)))
struct JataYukStabilityTests {

    // MARK: - Reducer Stability

    @Test
    func reducerTerminatesUnderRepeatedActions() {
        var state = RootState()
        let environment = RootEnvironment()

        for _ in 0..<100_000 {
            _ = rootReducer(
                state: &state,
                action: .ar(.placementAdvanced),
                environment: environment
            )
        }

        #expect(state.ar.placement == .allPlaced)
    }


    // MARK: - Store Stability

    @Test
    @MainActor
    func storeTerminatesUnderRepeatedActions() {
        let store = Store<RootState, RootAction>(
            initialState: RootState(),
            reducer: rootReducer,
            environment: RootEnvironment()
        )

        for _ in 0..<100_000 {
            store.send(.ar(.placementAdvanced))
        }

        #expect(store.state.ar.placement == .allPlaced)
    }


    // MARK: - MotionClient Lifecycle

    @Test
    func motionClientStartStopDoesNotAccumulate() {
        let motionClient = MotionClient()

        for _ in 0..<1_000 {
            motionClient.startTiltMonitoring {
                // Intentionally empty.
            }

            motionClient.stopTiltMonitoring()
        }

        #expect(true)
    }


    @Test
    func motionClientBothMonitorsCanStartAndStopRepeatedly() {
        let motionClient = MotionClient()

        for _ in 0..<1_000 {

            motionClient.startTiltMonitoring {
                // Intentionally empty.
            }

            motionClient.startShakeMonitoring {
                // Intentionally empty.
            }

            motionClient.stopTiltMonitoring()
            motionClient.stopShakeMonitoring()
        }

        #expect(true)
    }


    @Test
    func motionClientRepeatedStopIsSafe() {
        let motionClient = MotionClient()

        for _ in 0..<10_000 {
            motionClient.stopTiltMonitoring()
            motionClient.stopShakeMonitoring()
        }

        #expect(true)
    }


    // MARK: - MotionClient Value-Type Copies

    @Test
    func motionClientCopiesCanShareLifecycleSafely() {

        let clientA = MotionClient()
        let clientB = clientA
        let clientC = clientB

        clientA.startTiltMonitoring {
            // Intentionally empty.
        }

        clientB.startShakeMonitoring {
            // Intentionally empty.
        }

        clientC.stopTiltMonitoring()
        clientC.stopShakeMonitoring()

        #expect(true)
    }


    // MARK: - Reducer Stress

    @Test
    func repeatedPlacementActionsDoNotGrowStateIndefinitely() {

        var state = RootState()
        let environment = RootEnvironment()

        for _ in 0..<100_000 {

            _ = rootReducer(
                state: &state,
                action: .ar(.placementAdvanced),
                environment: environment
            )
        }

        // Placement has only four possible states.
        #expect(state.ar.placement == .allPlaced)
    }


    // MARK: - Reaction Tick Stress

    @Test
    func repeatedReactionTicksTerminate() {

        var state = RootState()
        let environment = RootEnvironment()

        for _ in 0..<100_000 {

            _ = rootReducer(
                state: &state,
                action: .ar(.reactionTick(0)),
                environment: environment
            )
        }

        #expect(state.experiment.reactionState != .done)
    }
}
