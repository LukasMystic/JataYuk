//
//  LoadingPageView.swift
//  JataYuk
//
//  Created by Miranda Khairunnisa on 12/08/26.
//

import SwiftUI

struct LoadingPageView: View {

    @ObservedObject var store: Store<RootState, RootAction>

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(customColors.appCream)
                    .ignoresSafeArea()

                Image("VolcanoBackground")
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(1.20)
                    .frame(
                        width: geometry.size.width,
                        height: geometry.size.height * 0.85
                    )
                    .frame(
                        maxHeight: .infinity,
                        alignment: .bottom
                    )
                
                VStack{
                    currentGuideCard.padding(.horizontal, 50)
                        .offset(y:-30)
                }
                
                VStack(spacing: 18) {
                    
                Spacer()

                pageDots

                Spacer().frame(height: 20)

                progressBar.frame(maxWidth: 420)

                Spacer().frame(height: geometry.size.height * 0.08)
                    }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            store.send(.loadingPage(.onAppear))
        }
        .onDisappear {
            store.send(.loadingPage(.onDisappear))
        }
    }

    @ViewBuilder
    private var currentGuideCard: some View {
        if store.state.loadingPage.guides.indices.contains(
            store.state.loadingPage.currentGuideIndex
        ) {
            GuideCardView(
                guide: store.state.loadingPage.guides[
                    store.state.loadingPage.currentGuideIndex
                ]
            )
        }
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(
                store.state.loadingPage.guides.indices,
                id: \.self
            ) { index in
                Circle()
                    .fill(
                        index == store.state.loadingPage.currentGuideIndex
                        ? Color.black.opacity(0.7)
                        : Color.black.opacity(0.25)
                    )
                    .frame(width: 6,height: 6
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
                    .fill(Color( red: 0.949, green: 0.729, blue: 0.216))
                    .frame(
                        width: geometry.size.width
                            * store.state.loadingPage.progress
                    )
                    .animation(
                        .linear(duration: 2.5),
                       value: store.state.loadingPage.progress
                    )
            }
        }
        .frame(height: 6)
    }
}
