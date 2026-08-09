//
//  ARExperimentView.swift
//  JataYuk
//
//  Created by Stanley Pratama Teguh on 29/07/26.
//

import SwiftUI

struct ARExperimentView: View {
    @ObservedObject var store: Store<RootState, RootAction>

    var body: some View {
        ZStack {
            ARViewContainer(store: store)
                .ignoresSafeArea()

            VStack {
                placementStatusView
                Spacer()
                debugControlsView
            }
            .padding()
        }
    }

    // Temporary placement phase indicator
    @ViewBuilder
    private var placementStatusView: some View {
        let label: String = {
            switch store.state.ar.placement {
            case .placingVolcano: return "Place the volcano"
            case .placingSideA:   return "Place Side A bench"
            case .placingSideB:   return "Place Side B bench"
            case .allPlaced:      return "Experiment ready"
            }
        }()
        Text(label)
            .font(.headline)
            .foregroundColor(.white)
            .padding(8)
            .background(.ultraThinMaterial)
            .cornerRadius(8)
    }

    private var debugControlsView: some View {
        HStack(spacing: 16) {
            if store.state.ar.placement == .allPlaced {
                Button("End") {
                    store.send(.navigate(to: .end))
                }
                .buttonStyle(.bordered)
                .tint(.white)
            }

            Button("?") {
                store.send(.overlay(.showInstruction))
            }
            .buttonStyle(.bordered)
            .tint(.white)
        }
    }
}
