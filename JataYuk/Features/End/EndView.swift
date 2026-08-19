//
//  EndView.swift
//  JataYuk
//
//  Created by Stanley Pratama Teguh on 29/07/26.
//

import SwiftUI
import Combine

struct EndView: View {
    @ObservedObject var store: Store<RootState, RootAction>

    // Drives EndAction.revealTick — same start-timestamp + tick pattern
    // ARAction.reactionTick uses for the volcano reaction itself.
    private let ticker = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {

            // MARK: - Background (live AR view, volcano already erupted)
            ARViewContainer(
                store: store,
                sessionResetToken: store.state.ar.sessionResetToken,
                isPaused: store.state.ar.isPaused
            )
            .ignoresSafeArea()

            // MARK: - Success overlay — all components appear together
            if store.state.end.isOverlayVisible {
                VStack(spacing: 22) {
                    //duarTitle
                    starRow
                    Spacer().frame(height: 4)
                    successBanner
                    experimentAgainButton
                }
                .padding(.top, 40)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .transition(.opacity)
            }

            // MARK: - Eye toggle — appears together with the overlay (i.e.
            // only once the controls have been auto-revealed), then stays
            // available so it can be used to hide/show afterward.
            if store.state.end.hasRevealedControls {
                eyeToggleButton
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: store.state.end.isOverlayVisible)
        .animation(.easeInOut(duration: 0.3), value: store.state.end.hasRevealedControls)
        .onReceive(ticker) { _ in
            guard let doneAt = store.state.end.volcanoDoneAt,
                  !store.state.end.hasRevealedControls else { return }
            store.send(.end(.revealTick(Date().timeIntervalSince(doneAt))))
        }
    }

    // MARK: - "duAR!" title (image asset)

//    private var duarTitle: some View {
//        Image("DuarWordmark")
//            .resizable()
//            .scaledToFit()
//            .frame(height: 60)
//            .padding(.bottom, 4)
//    }

    // MARK: - Star row (image asset, middle star bigger, matching Figma)

    private var starRow: some View {
        HStack(spacing: -6) {
            Image("StarIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 92, height: 92)
                .padding(.top, 40)
            Image("StarIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 128, height: 128)
            Image("StarIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 92, height: 92)
                .padding(.top, 40)
        }
    }

    // MARK: - Success message banner

    private var successBanner: some View {
        HStack(spacing: 8) {
            Text("🏅You have successfully completed the Experiment!")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.949, green: 0.729, blue: 0.216))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            Capsule().fill(Color.black.opacity(0.65))
        )
        .padding(.horizontal, 24)
    }

    // MARK: - Experiment Again button

    private var experimentAgainButton: some View {
        Button {
            // Reset the experiment/AR placement state, then jump back to
            // the start of the AR flow (not onboarding).
            store.send(.ar(.resetSession))
            store.send(.navigate(to: .ar))
        } label: {
            Text("Experiment Again")
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: 320)
                .padding(.vertical, 15)
                .background(
                    Capsule().fill(Color(red: 0.949, green: 0.729, blue: 0.216))
                )
        }
    }

    // MARK: - Eye toggle button (hide/show overlay to reveal the AR view)

    private var eyeToggleButton: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    store.send(.end(.toggleOverlay))
                } label: {
                    Image(systemName: store.state.end.isOverlayVisible ? "eye.fill" : "eye.slash.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(10)
                        .background(Circle().fill(Color(red: 0.949, green: 0.729, blue: 0.216)))
                }
            }
            Spacer()
        }
        .padding(.top, 16)
        .padding(.trailing, 16)
    }
}
