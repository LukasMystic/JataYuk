//
//  StatusPanelView.swift
//  JataYuk
//
//  View — bottom panel showing ingredient progress, status, and reset button.
//

import SwiftUI

struct StatusPanelView: View {
    @ObservedObject var viewModel: ReactionViewModel
    var onHide: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: statusSymbol)
                Text(statusText)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(statusColor)
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                ForEach(BeakerType.allCases, id: \.self) { beaker in
                    ingredientChip(beaker)
                }
            }

            Button(action: viewModel.reset) {
                Label("Reset Experiment", systemImage: "arrow.counterclockwise")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(alignment: .topTrailing) {
            Button(action: onHide) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                    .padding(8)
            }
        }
    }

    // MARK: - Private Helpers

    private var statusSymbol: String {
        switch viewModel.reactionState {
        case .idle:    return "flask"
        case .mixing:  return "plus.circle"
        case .failed:  return "exclamationmark.bubble"
        case .success: return "party.popper"
        }
    }

    private var statusText: String {
        switch viewModel.reactionState {
        case .idle:
            return "Tap a beaker to pick it up!"
        case .mixing:
            if !viewModel.isYeastLocked {
                return "Now add the Yeast catalyst!"
            }
            let remaining = BeakerType.allCases
                .filter { $0 != .yeast && !viewModel.pouredIngredients.contains($0) }
                .map(\.displayName)
                .joined(separator: " + ")
            return remaining.isEmpty ? "Pick up the Yeast!" : "Still need: \(remaining)"
        case .failed:
            return "Missing Dish Soap! Reset and try again 🫧"
        case .success:
            return "Elephant Toothpaste! 🐘"
        }
    }

    private var statusColor: Color {
        switch viewModel.reactionState {
        case .idle, .mixing: return .primary
        case .failed:        return .orange
        case .success:       return .green
        }
    }

    private func ingredientChip(_ beaker: BeakerType) -> some View {
        let poured = viewModel.pouredIngredients.contains(beaker)
        let locked = beaker == .yeast && viewModel.isYeastLocked

        return HStack(spacing: 4) {
            Image(systemName: poured ? "checkmark.circle.fill" : (locked ? "lock.fill" : "circle"))
                .font(.caption)
            Text(beaker.displayName)
                .font(.caption.bold())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(chipBackground(poured: poured, locked: locked), in: Capsule())
        .foregroundStyle(poured ? Color.green : (locked ? Color.secondary : Color.primary))
    }

    private func chipBackground(poured: Bool, locked: Bool) -> Color {
        if poured  { return Color.green.opacity(0.20) }
        if locked  { return Color.gray.opacity(0.15) }
        return Color.secondary.opacity(0.12)
    }
}
