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
            
            //Image("VolcanoBckg").resizeable().scaledtoFill()
            
            VStack(spacing: 80) {
                Text("Need a Break?")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.949, green: 0.729, blue: 0.216))
    

                VStack(spacing: 40) {
                    pauseButton("Resume", tint: Color(red: 0.949, green: 0.729, blue: 0.216)) {
                        store.send(.ar(.resumeSession))
                    }
                    pauseButton("Restart", tint: Color(red: 0.949, green: 0.729, blue: 0.216)) {
                        store.send(.ar(.resetSession))
                    }
                    pauseButton("Quit", tint: Color(red: 0.949, green: 0.729, blue: 0.216)) {
                        store.send(.navigate(to: .onboarding))
                    }
                }
                
            }
            .padding(80)
        }
    }

    private func pauseButton(_ label: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 24, weight: .semibold))
                //.foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(width: 382, height: 64)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(Color(red: 0.949, green: 0.729, blue: 0.216))
        )
        .contentShape(Capsule())
    }
}
