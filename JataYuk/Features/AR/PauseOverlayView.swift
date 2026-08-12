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
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)

            VStack(spacing: 24) {
                Text("Need a Break?")
                    .font(.largeTitle.bold())
                    .foregroundColor(.yellow)

                VStack(spacing: 16) {
                    pauseButton("Resume", tint: .yellow) {
                        store.send(.ar(.resumeSession))
                    }
                    pauseButton("Restart", tint: .yellow) {
                        store.send(.ar(.resetSession))
                    }
                    pauseButton("Quit", tint: .yellow) {
                        store.send(.navigate(to: .onboarding))
                    }
                }
            }
            .padding(40)
        }
    }

    private func pauseButton(_ label: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.title3.bold())
                .frame(maxWidth: 260)
                .padding(.vertical, 14)
                .background(tint)
                .foregroundColor(.black)
                .cornerRadius(12)
        }
    }
}
