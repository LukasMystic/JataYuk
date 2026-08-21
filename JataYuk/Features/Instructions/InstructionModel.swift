enum InstructionStepKey: Equatable {

    // MARK: AR Placement
    case placeVolcano
    case placeSideA
    case placeSideB

    // MARK: Neutral / side intros
    case introSolutions
    case sideAIntro
    case sideBIntro
    case moveCloserToBench

    // MARK: Ingredient "near" (first encounter, not yet poured)
    case h2o2Near
    case soapNear
    case foodColoringNear
    case yeastNear
    case waterNear

    // MARK: Holding / pouring — shared
    case bringToBeaker
    case pourIngredient
    case offerMore

    // MARK: Beaker
    case readyToMixSideA
    case readyToMixSideB
    case shakeToMix
    case maxPoursReached //added
    case sideComplete

    // MARK: AR Volcano
    case noSolutionsYet
    case interactVolcano
    case reacting
    case reactionDone
}

enum InstructionCopy {

    static let steps: [InstructionStep] = [

        // MARK: AR Placement

        .init(key: .placeVolcano, stepNumber: 0, context: .arPlacement,
              title: "Set up your experiment",
              description: "Point your camera at a flat surface, then tap to place the volcano and both ingredient stations all at once!",
              animation: nil),

        .init(key: .placeSideA, stepNumber: 1, context: .arPlacement,
              title: "Setting up…",
              description: "Placing your experiment on the surface.",
              animation: nil),

        .init(key: .placeSideB, stepNumber: 2, context: .arPlacement,
              title: "Setting up…",
              description: "Placing your experiment on the surface.",
              animation: nil),

        .init(key: .introSolutions, stepNumber: 3, context: .arPlacement,
              title: "Two solutions",
              description: "Ready to start? We’ll need to make 2 separate solutions, one on each ingredient set.\n\nLet's pick up any ingredient by moving closer to it.",
              animation: nil),

        .init(key: .moveCloserToBench, stepNumber: 4, context: .arPlacement,
              title: "Move closer",
              description: "Move closer to pick up an ingredient.",
              animation: nil),

        // MARK: Side A

        .init(key: .sideAIntro, stepNumber: 5, context: .arSideA,
              title: "Hydrogen peroxide solution",
              description: "Here, we'll be making hydrogen peroxide solution using dish soap and food coloring.",
              animation: nil),

        .init(key: .h2o2Near, stepNumber: 6, context: .arSideA,
              title: "Find the hydrogen peroxide",
              description: "Hydrogen peroxide is the main ingredient. Move closer and choose one of the three bottles. Each has a different strength or concentration.\n\nTap the right side of your screen to pick it up.",
              animation: nil),

        .init(key: .soapNear, stepNumber: 7, context: .arSideA,
              title: "Add the dish soap",
              description: "Now let's add the dish soap. These will create the foam.\n\nTap the right side of your screen to pick it up.",
              animation: nil),

        .init(key: .foodColoringNear, stepNumber: 8, context: .arSideA,
              title: "Add food coloring",
              description: "Let's add some color! Choose your favorite color by moving closer.\n\nTap the right side of your screen to pick it up.",
              animation: nil),

        .init(key: .readyToMixSideA, stepNumber: 9, context: .arSideA,
              title: "Time to mix",
              description: "Awesome! Your hydrogen peroxide solution is ready to mix.\n\nTap on the screen to start mixing.",
              animation: nil),

        // MARK: Side B

        .init(key: .sideBIntro, stepNumber: 10, context: .arSideB,
              title: "Yeast solution",
              description: "Here, we’ll mix yeast with water. This makes a catalyst that causes a chemical reaction to happen faster.",
              animation: nil),

        .init(key: .yeastNear, stepNumber: 11, context: .arSideB,
              title: "Pick up the yeast",
              description: "Let's add yeast using this spoon!\n\nTap the right side of your screen to pick it up.",
              animation: nil),

        .init(key: .waterNear, stepNumber: 12, context: .arSideB,
              title: "Add water",
              description: "To activate yeast, we'll need to add some water.\n\nTap the right side of your screen to pick it up. You can also adjust the temperature.",
              animation: nil),

        .init(key: .readyToMixSideB, stepNumber: 13, context: .arSideB,
              title: "Time to mix",
              description: "Great job! Your yeast solution is ready to mix\n\nTap on the screen to start mixing.",
              animation: nil),

        // MARK: Shared holding / pouring

        .init(key: .bringToBeaker, stepNumber: 14, context: .arSideA,
              title: "Bring it over",
              description: "Move closer to the beaker to bring it over.",
              animation: nil),

        .init(key: .pourIngredient, stepNumber: 15, context: .arSideA,
              title: "Pour",
              description: "Tilt your iPad to pour.",
              animation: nil),

        .init(key: .offerMore, stepNumber: 16, context: .arSideA,
              title: "Add more?",
              description: "Great job pouring it in! Add at least one of each ingredient.\n\n(Tip: Add more of the same ingredient for a different reaction.)",
              animation: nil),

        .init(key: .shakeToMix, stepNumber: 17, context: .arSideA,
              title: "Shake",
              description: "Now shake your iPad gently to mix everything together!",
              animation: nil),

        .init(key: .sideComplete, stepNumber: 18, context: .arSideA,
              title: "Side complete",
              description: "Great job! Let's move over to the other ingredient set to make the next solution.",
              animation: nil),

        // MARK: AR Volcano
        .init(key: .noSolutionsYet, stepNumber: 19, context: .arVolcano,
              title: "Combine the solutions",
              description: "Start on one of the benches!",
              animation: nil),
        
        .init(key: .interactVolcano, stepNumber: 20, context: .arVolcano,
              title: "Combine the solutions",
              description: "Are you ready to combine both solutions and see what happens? \n\nLet's move back to our volcano!Tap on the screen to combine both solutions!",
              animation: nil),

        .init(key: .reacting, stepNumber: 21, context: .arVolcano,
              title: "Watch closely!",
              description: "Look! The chemical reaction is happening!",
              animation: nil),

        .init(key: .reactionDone, stepNumber: 22, context: .arVolcano,
              title: "Reaction complete",
              description: "Look at that foamy explosion! The hydrogen peroxide is breaking into water and oxygen quickly because of the catalyst.\n\nThink you can make the explosion even bigger? How?",
              animation: nil)
    ]

    static func step(for key: InstructionStepKey) -> InstructionStep {
        steps.first { $0.key == key }!
    }
}
