//
//  SloshControls.swift
//  WaterSim
//
//  Created by jatayumuw on 15/08/26.
//

import SwiftUI

struct SloshControls: View {
    @Bindable var settings: SloshSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            knob("Viscosity", value: $settings.viscosity, range: 0...1)
            knob("Dynamic vertices", value: $settings.dynamicVertices, range: 0...1)
            knob("Default height", value: $settings.defaultHeight, range: 0.05...0.95)
            Toggle("Can decrement height", isOn: $settings.canDecrement)
                .tint(.cyan)
            knob("Decrement value", value: $settings.decrementValue, range: 0.01...0.3)
                .opacity(settings.canDecrement ? 1 : 0.4)
                .disabled(!settings.canDecrement)
            Button("Decrement") {
                settings.decrement()
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(.borderedProminent)
            .tint(.cyan)
            .disabled(!settings.canDecrement)
        }
        .font(.caption)
        .foregroundStyle(.white)
        .padding(12)
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 12)
        .padding(.bottom, 16)
    }

    private func knob(_ title: String, value: Binding<Float>, range: ClosedRange<Float>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: "%.2f", value.wrappedValue))
                    .monospacedDigit()
            }
            Slider(value: value, in: range)
                .tint(.cyan)
        }
    }
}
