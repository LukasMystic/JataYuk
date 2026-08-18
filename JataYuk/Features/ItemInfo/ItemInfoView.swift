//
//  ItemInfoView.swift
//  JataYuk
//
//  Created by Miranda Khairunnisa on 15/08/26.
//


import SwiftUI

struct ItemInfoView: View {
    @ObservedObject var store: Store<RootState, RootAction>
    let item: BeakerType

    private var info: ItemInfo { .info(for: item) }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Scrim — tap outside the card to dismiss, same gesture children expect from
                // any modal sheet.
                Color.black.opacity(0.45).ignoresSafeArea().onTapGesture(perform: close)
                
                HStack {
                    card
                        .frame(width: geometry.size.width * 0.5)
                        .padding(.leading, 24)
                    
                    Spacer()
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
            .animation(.easeInOut(duration: 0.2), value: item)
        }
    }

    // MARK: - Card

    private var card: some View {
        VStack(alignment: .leading, spacing: 20) {
            closeButton
            titleBlock

            VStack(alignment: .leading, spacing: 18) {
                ForEach(
                    Array(info.sections.enumerated()),
                    id: \.element.id
                ) { index, section in
                    sectionRow(
                        section,
                        isMascotOnLeft: index % 2 != 0
                    )
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(red: 0.09, green: 0.09, blue: 0.11))
                .shadow(color: .black.opacity(0.35), radius: 20, y: 10)
        )
    }

    // MARK: - Close (back chevron, top-leading inside the card)

    private var closeButton: some View {
        Button(action: close) {
            Image(systemName: "chevron.left")
                .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background {
                                Capsule().fill(Color(red: 0.949, green: 0.729, blue: 0.216).opacity(0.85)
                                    )
                                    .glassEffect()
                            }
                    }
                    .buttonStyle(.plain)
    }

    // MARK: - Title + tagline

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(info.title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text(info.description)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.yellow)
        }
    }

    // MARK: - Section row

    private func sectionRow(_ section: ItemInfoSection, isMascotOnLeft: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {

            if isMascotOnLeft {
                mascot(for: section)
            }

            sectionContent(section)

            if !isMascotOnLeft {
                mascot(for: section)
            }
        }
    }

    // MARK: - Section Content

    private func sectionContent(_ section: ItemInfoSection) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(section.heading)
                .font(.headline)
                .foregroundColor(.white)

            Text(section.body)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Mascot

    @ViewBuilder
    private func mascot(for section: ItemInfoSection) -> some View {
        if let imageName = section.mascotImageName {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
        }
    }

    private func close() {
        store.send(.overlay(.hideItemInfo))
    }
}
