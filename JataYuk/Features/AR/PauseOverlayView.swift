//
//  PauseOverlayView.swift
//  JataYuk
//
//  Created by Stanley Pratama Teguh on 12/08/26.
//

import SwiftUI

struct PauseOverlayView: View {
    @ObservedObject var store: Store<RootState, RootAction>

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Blur layer
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
                
                // Background
                Image("VolcanoBackground")
                    .resizable()
                    .scaleEffect(1.20)
                    .frame(
                        width: geometry.size.width,
                        height: geometry.size.height * 0.85
                    )
                    .frame(
                        maxHeight: .infinity,
                        alignment: .bottom
                    )
                    .opacity(0.50)


                // Dark layer
                Color.black
                    .opacity(0.3)
                    .ignoresSafeArea()

                // Controls
                VStack(spacing: 80) {
                    Text("Need a Break?")
                        .font(.custom("Fredoka-Bold", size: 64))
                        .foregroundStyle(customColors.appYellow)

                    VStack(spacing: 40) {
                        pauseButton("Resume", tint: customColors.appYellow) {
                            store.send(.ar(.resumeSession))
                        }

                        pauseButton("Restart", tint: customColors.appYellow) {
                            store.send(.ar(.resetSession))
                        }

                        pauseButton("Quit", tint: customColors.appYellow) {
                            store.send(.navigate(to: .onboarding))
                        }
                    }
                }
                .frame(
                    width: geometry.size.width,
                    height: geometry.size.height,
                    alignment: .center
                )
            }
            .ignoresSafeArea()
        }
    }

    private func pauseButton(_ label: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.custom("Fredoka-Medium", size:24))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(width: 382, height: 64)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(customColors.appYellow)
        )
        .contentShape(Capsule())
    }
}
