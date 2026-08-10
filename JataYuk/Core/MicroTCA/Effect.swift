//
//  Effect.swift
//  JataYuk
//
//  Created by Stanley Pratama Teguh on 05/08/26.

import Foundation

struct Effect {
    let run: (@escaping (any Any) -> Void) async -> Void

    static func none() -> Effect {
        Effect { _ in }
    }
}
