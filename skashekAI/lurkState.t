// Skashek moving and hunting for the player
skashekLurkState: SkashekAIState {
    stateName = 'Lurk State'
    
    doPerception() {
        //TODO: Handle Skashek sound perception
    }

    doPlayerPeek() {
        //TODO: Player peeks in while he is in the room
    }

    doPlayerCaughtLooking() {
        //TODO: The player sees Skashek through a grate or cat flap,
        // but Skashek was ready!
        //TODO: Do not accept this if it happened last turn
    }

    describePeekedAction() {
        //TODO: Allow for him to be described according to his current action
        "<.p><i>\^<<gSkashekName>> is in there!</i> ";
    }

    doTurn() {
        //
    }
}