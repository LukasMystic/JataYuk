//
//  PlacementHintView.swift
//  JataYuk
//
//  Created by Stanley Pratama Teguh on 04/08/26.
//

import SwiftUI

struct PlacementHintView: View {
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 54))
                    .foregroundStyle(.white)
                    .scaleEffect(pulse ? 1.10 : 0.92)
                    .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: pulse)

                Text("Move iPad slowly to detect a flat surface")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Then tap to place the beakers")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
            .padding(.horizontal, 44)

            Spacer().frame(height: 130)
        }
        .onAppear { pulse = true }
    }
}

#Preview { PlacementHintView() }
