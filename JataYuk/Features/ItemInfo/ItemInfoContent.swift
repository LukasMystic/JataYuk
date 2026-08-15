//
//  ItemInfoContent.swift
//  JataYuk
//
//  Created by Miranda Khairunnisa on 15/08/26.
//

import Foundation

// MARK: - Item Info Section (not sure where to place this)

struct ItemInfoSection: Equatable, Identifiable {
    var id: String { heading }
    var heading: String
    var body: String
    var mascotImageName: String?
}

// MARK: - Copywriting

extension ItemInfo {

    static func info(for type: BeakerType) -> ItemInfo {

        switch type {

        // MARK: Hydrogen Peroxide

        case .h2o2:
            return ItemInfo(
                beakerType: .h2o2,
                title: "Hydrogen Peroxide",
                description: "Everything that you need to know about Hydrogen Peroxide",
                sections: [
                    ItemInfoSection(
                        heading: "👀 What is it?",
                        body: """
                        Hydrogen peroxide is a clear liquid that looks almost exactly like water, but it's actually a different substance.
                        """
//                        mascotImageName: nil
                    ),

                    ItemInfoSection(
                        heading: "🫧 What's inside it?",
                        body: """
                        It's made from tiny particles called atoms. Each tiny piece has 2 hydrogen atoms and 2 oxygen atoms (H₂O₂). That's one more oxygen atom than water (H₂O)!
                        """
//                        mascotImageName: nil
                    ),

                    ItemInfoSection(
                        heading: "💭 Think of it like…",
                        body: """
                        Imagine carrying an extra balloon. Hydrogen peroxide is carrying an extra oxygen that can be released later.
                        """
//                        mascotImageName: nil
                    ),
                    
                    ItemInfoSection(
                        heading: "🔍 Where can you find it?",
                        body: """
                        You can find diluted hydrogen peroxide in some first aid kits and pharmacies. Adults sometimes use it to clean small cuts.
                        """
//                        mascotImageName: nil
                    ),
                    
                    ItemInfoSection(
                        heading: "️⚠️ Safety Precautions!",
                        body: """
                        • Don't drink it.
                        • Keep it away from your eyes.
                        • Always use it with an adult.
                        """
//                        mascotImageName: nil
                    )
                ]
            )

        // MARK: Dish Soap

        case .soap:
            return ItemInfo(
                beakerType: .soap,
                title: "Dish Soap",
                description: "Everything that you need to know about Dish Soap",
                sections: [
                    ItemInfoSection(
                        heading: "👀 What is it?",
                        body: """
                        Dish soap is a cleaning liquid used to wash dishes, cups, and pans. It helps remove grease and food stuck on them.
                        """
//                        mascotImageName: nil
                    ),

                    ItemInfoSection(
                        heading: "🫧 What's inside it?",
                        body: """
                        Dish soap contains special cleaning ingredients that like to mix with both water and oily things. That's why it helps wash away dirt so easily.
                        """
//                        mascotImageName: nil
                    ),

                    ItemInfoSection(
                        heading: "💭 Think of it like…",
                        body: """
                        Imagine a superhero that helps water grab onto greasy messes so they can be washed away.
                        """
//                        mascotImageName: nil
                    ),
                    
                    ItemInfoSection(
                        heading: "🔍 Where can you find it?",
                        body: """
                        You can find dish soap next to the kitchen sink, in supermarkets, or at the grocery stores. Almost every home has a bottle of dish soap.
                        """
//                        mascotImageName: nil
                    ),
                    
                    ItemInfoSection(
                        heading: "️⚠️ Safety Precautions!",
                        body: """
                        • Don't drink it.
                        • Keep it away from your eyes.
                        • Wipe up spills so no one slips.
                        """
//                        mascotImageName: nil
                    )
                ]
            )

        // MARK: Yeast

        case .yeast:
            return ItemInfo(
                beakerType: .yeast,
                title: "Yeast",
                description: "Everything that you need to know about Yeast",
                sections: [
                    ItemInfoSection(
                        heading: "👀 What is it?",
                        body: """
                        Yeast is a tiny living thing. It's so small that you need a microscope to see it! Millions of yeast can fit on the tip of your finger.
                        """
//                        mascotImageName: nil
                    ),

                    ItemInfoSection(
                        heading: "🫧 What's inside it?",
                        body: """
                        Yeast is made of tiny cells, just like plants, animals, and people. Even though it's alive, it doesn't have eyes, arms, or legs.
                        """
//                        mascotImageName: nil
                    ),

                    ItemInfoSection(
                        heading: "💭 Think of it like…",
                        body: """
                        Imagine thousands of tiny invisible helpers working together. You can't see them one by one, but together they can do amazing things.
                        """
//                        mascotImageName: nil
                    ),
                    
                    ItemInfoSection(
                        heading: "🔍 Where can you find it?",
                        body: """
                        You can find yeast in grocery stores, in the baking aisles. Yeast is used in bread and pizza dough recipes that helps them become soft and fluffy.
                        """
//                        mascotImageName: nil
                    ),
                    
                    ItemInfoSection(
                        heading: "️⚠️ Safety Precautions!",
                        body: """
                        • Safe to touch with clean hands.
                        • Don't eat dry yeat by itself.
                        • Wash your hand after using it.
                        """
//                        mascotImageName: nil
                    )
                ]
            )

        // MARK: Water

        case .water:
            return ItemInfo(
                beakerType: .water,
                title: "Water",
                description: "Everything that you need to know about Water",
                sections: [
                    ItemInfoSection(
                        heading: "👀 What is it?",
                        body: """
                        Water is a liquid that living things need to survive. We drink it, use it to wash, cook with it, and even find it in the air and inside our bodies!
                        """
//                        mascotImageName: nil
                    ),

                    ItemInfoSection(
                        heading: "🫧 What's inside it?",
                        body: """
                        Water is made of tiny particles called molecules. Each water molecule is made from two hydrogen atoms and one oxygen atom. That's why scientists write it as H₂O.

                        Think of each molecule like a tiny team: two hydrogen atoms holding onto one oxygen atom!₂O)!
                        """
//                        mascotImageName: nil
                    ),

                    ItemInfoSection(
                        heading: "💭 Think of it like…",
                        body: """
                        Think of water as a universal helper. It can mix with and carry many different things, which is why it is useful for making drinks, growing plants, cleaning, and doing science experiments.
                        """
//                        mascotImageName: nil
                    ),
                    
                    ItemInfoSection(
                        heading: "🔍 Where can you find it?",
                        body: """
                        You can find water almost everywhere! 🌎
                        • Taps and drinking bottles for drinking
                        • In nature in the form of rain, puddles, rivers, lakes, oceans, snow, and ice
                        • Inside plants and even inside your body!
                        """
//                        mascotImageName: nil
                    ),
                    
                    ItemInfoSection(
                        heading: "️⚠️ Safety Precautions!",
                        body: """
                        Water is usually safe to handle, but hot water can burn you.
                        For this experiment:
                        • Ask an adult to help with the electric kettle.
                        • Never touch the hot water or kettle with your bare hands.
                        • Make sure the water isn't too hot before using it with the yeast.
                        • Follow the experiment instructions and safety guidance from your adult.
                        """
//                        mascotImageName: nil
                    )
                ]
            )

        // MARK: Food Coloring

        case .foodColoring:
            return ItemInfo(
                beakerType: .foodColoring,
                title: "Food Coloring",
                description: "Everything that you need to know about Food Coloring",
                sections: [
                    ItemInfoSection(
                        heading: "👀 What is it?",
                        body: """
                        Food coloring is a special liquid or gel that adds bright colors to food and drinks.
                        """
//                        mascotImageName: nil
                    ),

                    ItemInfoSection(
                        heading: "🫧 What's inside it?",
                        body: """
                        It contains tiny color particles that spread through food or liquids, making them look more colorful.
                        """
//                        mascotImageName: nil
                    ),

                    ItemInfoSection(
                        heading: "💭 Think of it like…",
                        body: """
                        It's like adding a drop of paint to water. It changes the color without changing what the water is.
                        """
//                        mascotImageName: nil
                    ),
                    
                    ItemInfoSection(
                        heading: "🔍 Where can you find it?",
                        body: """
                        You can find food coloring in the baking aisles at the grocery stores or in cake decorating shops. People often use it to decorate cakes, cookies, and desserts.
                        """
//                        mascotImageName: nil
                    ),
                    
                    ItemInfoSection(
                        heading: "️⚠️ Safety Precautions!",
                        body: """
                        • It's made for food, but only use a small amount.
                        • It can stain your hands, clothes, and tables.
                        • Clean up spills quickly.
                        """
//                        mascotImageName: nil
                    )
                ]
            )
        }
    }
}
