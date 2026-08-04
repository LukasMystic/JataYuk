//
//  ContentView.swift
//  JataYuk
//
//  Created by Stanley Pratama Teguh on 04/08/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ReactionViewModel()
    @State private var isPanelVisible = true

    var body: some View {
        ZStack {
            ARViewContainer(viewModel: viewModel)
                .edgesIgnoringSafeArea(.all)

            if !viewModel.isPlaced {
                PlacementHintView()
            }

            if viewModel.selectedBeaker != nil {
                PourPromptView(viewModel: viewModel, onDismiss: viewModel.deselectBeaker)
                    .transition(.opacity)
            }

            if viewModel.isPlaced && viewModel.selectedBeaker == nil {
                VStack {
                    Spacer()
                    if isPanelVisible {
                        StatusPanelView(viewModel: viewModel, onHide: {
                            withAnimation(.spring(duration: 0.35)) { isPanelVisible = false }
                        })
                        .padding(.horizontal, 24)
                        .padding(.bottom, 44)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        HStack {
                            Spacer()
                            Button {
                                withAnimation(.spring(duration: 0.35)) { isPanelVisible = true }
                            } label: {
                                Label("Show Panel", systemImage: "flask.fill")
                                    .font(.subheadline.bold())
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(.ultraThinMaterial, in: Capsule())
                                    .foregroundStyle(.primary)
                            }
                            .padding(.trailing, 24)
                        }
                        .padding(.bottom, 44)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
        }
        .onChange(of: viewModel.isPlaced) { _, placed in
            if placed { viewModel.startMotionDetection() }
        }
        .onDisappear { viewModel.stopMotionDetection() }
    }
}

#Preview { ContentView() }
