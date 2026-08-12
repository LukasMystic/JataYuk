//
//  LoadingPageView.swift
//  JataYuk
//
//  Created by Miranda Khairunnisa on 12/08/26.
//

import SwiftUI

struct LoadingPageView: View {

    @ObservedObject var store: Store<
        LoadingPageState,
        LoadingPageAction
    >

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(
                        red: 0.965,
                        green: 0.945,
                        blue: 0.902
                    )
                    .ignoresSafeArea()

                    Image("VolcanoBackground")
                        .resizable()
                        .scaledToFill()
                        .frame(
                                    width: geometry.size.width,
                                    height: geometry.size.height * 0.85
                                )
                                .clipped()
                                .frame(
                                    maxHeight: .infinity,
                                    alignment: .bottom
                                )

                VStack(spacing: 18) {
                    Spacer()
                        .frame(
                            height: geometry.size.height * 0.25
                        )

                    currentGuideCard
                        .frame(height: 550)
                        .padding(.horizontal, 40)

                    pageDots

                    progressBar
                        .frame(maxWidth: 420)

                    Spacer()
                }
            }
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        .ignoresSafeArea()
        .onAppear {
            store.send(.onAppear)
        }
        .onDisappear {
            store.send(.onDisappear)
        }
    }

    @ViewBuilder
    private var currentGuideCard: some View {
        if store.state.guides.indices.contains(
            store.state.currentGuideIndex
        ) {
            GuideCardView(
                guide: store.state.guides[
                    store.state.currentGuideIndex
                ]
            )
        }
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(
                store.state.guides.indices,
                id: \.self
            ) { index in
                Circle()
                    .fill(
                        index == store.state.currentGuideIndex
                        ? Color.black.opacity(0.7)
                        : Color.black.opacity(0.25)
                    )
                    .frame(
                        width: 6,
                        height: 6
                    )
            }
        }
    }

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.black.opacity(0.15))

                Capsule()
                    .fill(
                        Color(
                            red: 0.949,
                            green: 0.729,
                            blue: 0.216
                        )
                    )
                    .frame(
                        width: geometry.size.width
                            * store.state.progress
                    )
                    .animation(
                        .linear(duration: 2.5),
                       value: store.state.progress
                    )
            }
        }
        .frame(height: 6)
    }
}

#Preview(traits: .landscapeLeft) {
    LoadingPageView(
        store: Store(
            initialState: LoadingPageState(),
            reducer: LoadingPageReducer.reduce,
            environment: RootEnvironment()
        )
    )
}
