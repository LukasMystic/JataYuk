//
//  PourPromptView.swift
//  JataYuk
//
//  Created by Stanley Pratama Teguh on 04/08/26.
//

import SwiftUI

struct PourPromptView: View {
    @ObservedObject var viewModel: ReactionViewModel
    let onDismiss: () -> Void

    @State private var arrowPhase = false
    @State private var shakeOffset: CGFloat = 0

    private var beaker: BeakerType { viewModel.selectedBeaker ?? .h2o2 }

    private var amountBinding: Binding<Double> {
        switch beaker {
        case .h2o2: return $viewModel.h2o2Amount
        case .soap: return $viewModel.soapAmount
        case .yeast: return .constant(1.0)
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.30)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onDismiss() }

            VStack(spacing: 20) {
                Image(systemName: beaker.sfSymbol)
                    .font(.system(size: 46))
                    .foregroundStyle(accentColor)

                Text(beaker.displayName).font(.title.bold())

                Divider().padding(.horizontal)

                if beaker.useShake {
                    shakeInstruction
                } else {
                    HStack(alignment: .center, spacing: 20) {
                        tiltInstruction.frame(maxWidth: .infinity)
                        verticalAmountSlider
                    }
                }

                Button("Put Back", action: onDismiss)
                    .buttonStyle(.bordered)
                    .tint(.secondary)
            }
            .padding(28)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
            .shadow(radius: 12)
            .padding(.horizontal, 44)
        }
    }

    private var verticalAmountSlider: some View {
        VStack(spacing: 8) {
            Text("\(Int(amountBinding.wrappedValue * 100))%")
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(accentColor)

            Slider(value: amountBinding, in: 0.1...1.0)
                .rotationEffect(.degrees(-90))
                .frame(width: 150)
                .frame(width: 44, height: 150)
                .tint(accentColor)

            Text("Amount").font(.caption.bold()).foregroundStyle(.secondary)
        }
    }

    private var tiltInstruction: some View {
        VStack(spacing: 14) {
            HStack(spacing: 28) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(accentColor)
                    .opacity(arrowPhase ? 1.0 : 0.20)
                Image(systemName: "ipad.landscape").font(.system(size: 48))
                Image(systemName: "arrow.right")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(accentColor)
                    .opacity(arrowPhase ? 0.20 : 1.0)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 0.65).repeatForever(autoreverses: true)) {
                    arrowPhase = true
                }
            }
            Text("Tilt Left or Right").font(.title2.bold())
            Text("to pour \(beaker.displayName) into the reaction vessel")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var shakeInstruction: some View {
        VStack(spacing: 14) {
            Image(systemName: "ipad.landscape")
                .font(.system(size: 58))
                .offset(x: shakeOffset)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.09).repeatForever(autoreverses: true)) {
                        shakeOffset = 14
                    }
                }
            Text("Shake your iPad!").font(.title2.bold())
            Text("to pour the Yeast catalyst into the reaction vessel")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var accentColor: Color {
        switch beaker {
        case .h2o2: return .yellow
        case .soap: return Color(red: 0.1, green: 0.80, blue: 0.45)
        case .yeast: return .orange
        }
    }
}
