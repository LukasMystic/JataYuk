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
                .font(.subheadline)
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 480, alignment: .leading)
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 20)
        .background(Color.black.opacity(0.75)) //change color later
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(alignment: .trailing) {
//            Image("Mascot")
        }
        .padding(.trailing, 44) // room for the mascot spilling past the bubble edge
    }
}
 

