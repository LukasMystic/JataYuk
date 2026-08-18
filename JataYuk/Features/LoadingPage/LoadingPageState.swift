//
//  LoadingPageState.swift
//  JataYuk
//
//  Created by Miranda Khairunnisa on 12/08/26.
//

import Foundation

// MARK: - LoadingPageState

struct LoadingPageState: Equatable {
    var progress: Double = 0.0
    var currentGuideIndex: Int = 0
    var isLoadingComplete: Bool = false
    
    var guides: [GuideCard] = GuideData.guides
}
