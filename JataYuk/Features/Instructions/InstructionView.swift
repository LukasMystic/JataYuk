//
//  InstructionView.swift
//  JataYuk
//
//  Created by Miranda Khairunnisa on 16/08/26.
//

import SwiftUI

struct InstructionView: View {
    let step: InstructionStep?

    var body: some View {
        Group {
            if let step {
                bubble(for: step)
                    .transition(.opacity)
                    .id(step.key) // forces a transition when the instruction changes
            }
        }
        .animation(.easeInOut(duration: 0.5), value: step?.key)
    }

    @ViewBuilder
    private func bubble(for step: InstructionStep) -> some View {
        HStack(alignment: .top) {
            Text(step.description)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 480, alignment: .leading)
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 20)
        .background(customColors.appBlack.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(alignment: .trailing
        
        
        
        
        ) {
            Image("Mascot")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .scaleEffect(1.5)
                .offset(x: 40)
                .rotationEffect(.degrees(5))
                .shadow(color: .white.opacity(0.6), radius: 10, x: 4, y: 4)
        }
        .padding(.trailing, 44) // room for the mascot spilling past the bubble edge
    }
}
