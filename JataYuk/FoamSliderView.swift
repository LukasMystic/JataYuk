//
//  FoamSliderView.swift
//  JataYuk
//
//  Created by Teresa Tendeas on 06/08/26.
//

import SwiftUI

/// One labelled whole-number slider. A SwiftUI Slider works in Double, so this
/// bridges to an Int with a fixed step and snaps the value.
private struct IntSliderRow: View {
    let title: String
    let unit: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int

    private var doubleBinding: Binding<Double> {
        Binding(
            get: { Double(value) },
            set: { newValue in
                // Snap relative to lowerBound, not zero — otherwise a range like
                // 3…7 step 2 rounds to multiples of 2 (4,6,8) instead of 3,5,7.
                let steps = ((newValue - Double(range.lowerBound)) / Double(step)).rounded()
                let snapped = range.lowerBound + Int(steps) * step
                value = min(range.upperBound, max(range.lowerBound, snapped))
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title).font(.subheadline.weight(.medium))
                Spacer()
                Text("\(value) \(unit)")
                    .font(.subheadline.monospacedDigit().bold())
                    .foregroundStyle(.tint)
            }
            Slider(value: doubleBinding,
                   in: Double(range.lowerBound)...Double(range.upperBound),
                   step: Double(step))
        }
    }
}

/// The five chemistry inputs the user sets before the reaction erupts.
struct FoamSlidersView: View {
    @ObservedObject var viewModel: ReactionViewModel

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                Text("Recipe").font(.subheadline.bold())
                Spacer()
            }
            .foregroundStyle(.secondary)

            IntSliderRow(title: "H₂O₂ concentration", unit: "%",
                         value: $viewModel.concentration, range: 3...7, step: 2)
            IntSliderRow(title: "H₂O₂ amount", unit: "mL",
                         value: $viewModel.volumeML, range: 100...500, step: 100)
            IntSliderRow(title: "Dish soap", unit: "tbsp",
                         value: $viewModel.soapTbsp, range: 1...5, step: 1)
            IntSliderRow(title: "Yeast", unit: "tbsp",
                         value: $viewModel.yeastTbsp, range: 1...5, step: 1)
            IntSliderRow(title: "Water temperature", unit: "°C",
                         value: $viewModel.temperatureC, range: 20...50, step: 1)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .tint(.cyan)
    }
}
