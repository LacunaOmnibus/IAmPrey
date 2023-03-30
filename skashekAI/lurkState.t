// Skashek moving and hunting for the player
skashekLurkState: SkashekAIState {
    stateName = 'Lurk State'

    checkableRooms = [
        northwestCubicle,
        northeastCubicle,
        southwestCubicle,
        southeastCubicle,
        armory,
        assemblyShop,
        breakroom,
        cloneQuarters,
        commonRoom,
        deliveryRoom,
        directorsOffice,
        enrichmentRoom,
        evaluationRoom,
        freezer,
        humanQuarters,
        storageBay,
        kitchen,
        labA,
        labB,
        library,
        lifeSupportTop,
        reservoir,
        securityOffice,
        serverRoomTop
    ]

    roomsLeftToCheck = static new Vector(checkableRooms.length)

    goalRoom = deliveryRoom
    startRandom = nil
    currentStep = 1
    stepsInStride = 2
    inspectionTurns = 0
    creepTurns = 0
    creepingWithClicking = nil
    suspendCreeping = nil
    doorSlammedInFace = nil
    leewayExpired = nil
    temporaryGoal = nil // For when he saw something wrong
    soundGoal = nil // For when he heard something weird
    lastSoundDistance = 1000 // How far away was the last soundGoal?

    resetRoomList() {
        #if __DEBUG_SKASHEK_ACTIONS
        "<.p>
        LURK: Resetting room list...
        <.p>";
        #endif
        if (roomsLeftToCheck.length > 0) {
            roomsLeftToCheck.removeRange(1, -1);
        }
        for (local i = 1; i <= checkableRooms.length; i++) {
            roomsLeftToCheck.append(checkableRooms[i]);
        }
    }

    disqualifyCurrentRoom() {
        if (roomsLeftToCheck.length > 0) {
            local index = roomsLeftToCheck.indexOf(skashek.getOutermostRoom());
            if (index != nil) {
                // Do not try to check the room we are currently in.
                roomsLeftToCheck.removeElementAt(index);
            }
        }
    }

    checkForRoomRefresh() {
        if (roomsLeftToCheck.length == 0) {
            resetRoomList();
            disqualifyCurrentRoom();
        }
    }

    chooseNewRoom() {
        disqualifyCurrentRoom();
        checkForRoomRefresh();
        local nextIndex = getRandomResult(roomsLeftToCheck.length);
        goalRoom = roomsLeftToCheck[nextIndex];
        roomsLeftToCheck.removeElementAt(nextIndex);
        checkForRoomRefresh();
        #if __DEBUG_SKASHEK_ACTIONS
        "<.p>
        LURK: Chose new room: <<goalRoom.roomTitle>>
        <.p>";
        #endif
    }

    start(prevState) {
        #ifdef __DEBUG
        setupForTesting();
        #endif
        inspectionTurns = 0;
        creepTurns = 0;
        suspendCreeping = nil;
        doorSlammedInFace = nil;
        leewayExpired = nil;
        temporaryGoal = nil;
        soundGoal = nil;
        lastSoundDistance = 1000;
        currentStep = 1;
        if (startRandom) {
            resetRoomList();
            chooseNewRoom();
        }
        else {
            #if __DEBUG_SKASHEK_ACTIONS
            "<.p>
            LURK: Chose new room: <<goalRoom.roomTitle>>
            <.p>";
            #endif
        }
    }

    end(nextState) {
        startRandom = true;
    }

    #ifdef __DEBUG
    setupForTesting() {
        inherited();
        startRandom = nil;
        goalRoom = labA;
    }
    #endif

    nextStopInRoute() {
        if (temporaryGoal != nil) return temporaryGoal;
        if (soundGoal != nil) return soundGoal;
        return goalRoom;
    }
    
    doPerception(impact) {
        #if __DEBUG_SKASHEK_ACTIONS
        "<.p>
        LURK: Heard <b><<impact.sourceOrigin.theName>></b>!";
        impact.soundProfile.afterEmission(
            impact.sourceOrigin.getOutermostRoom()
        );
        "<.p>";
        #endif
        followSound(impact);
    }

    playerWillGetCaughtPeeking() {
        return creepTurns > 0;
    }

    //doPlayerPeek() { }

    doPlayerCaughtLooking() {
        if (doorSlammedInFace) {
            "<<getPeekHeIs()>> rubbing his forehead in pain.
            {I} seem to have gotten him good with that door slam!
            <i>{I} should really take this opportunity to escape, though!</i> ";
            return;
        }
        if (creepTurns <= 0) return;
        "<q>Why, hello there, Prey...!</q> <<getPeekHe()>> cackles.
        <q>If you ever needed a reason to run, then I'm
        <i>coming in!</i></q> ";
        // Punish the player for peeking
        creepTurns = 0;
        suspendCreeping = true;
    }

    describePeekedAction() {
        if (creepTurns > 0) {
            "<<getPeekHeIs(true)>> right there,
            and he knows {i}{'m} in here...! ";
        }
        else if (inspectionTurns > 0) {
            describeNonTravelAction();
        }
        else {
            local approachArray = skashek.getApproach();
            describeApproach(approachArray);
        }
    }

    showPeekAfterTurn(canSeePlayer) {
        return showsDuringPeek() || inspectionTurns > 0;
    }

    addSpeedBoost(turns) {
        currentStep = stepsInStride + (turns - 1);
    }

    receiveDoorSlam() {
        suspendCreeping = nil;
        creepTurns = 2;
        creepingWithClicking = nil;
        doorSlammedInFace = true;
    }

    startCreeping() {
        if (temporaryGoal != nil) return nil;
        if (soundGoal != nil) return nil;
        if (suspendCreeping) return nil;
        local approachArray = skashek.getApproach();
        local nextRoom = approachArray[1];
        local connector = approachArray[2].connector;
        if (!skashek.peekInto(nextRoom)) return nil;
        if (!connector.ofKind(Door)) return nil;
        if (connector.lockability == lockableWithKey) return nil;
        if (!hasSeenPreyOutsideOfDeliveryRoom && nextRoom == deliveryRoom) {
            // Don't creep if Skashek is on the way to check on the player
            return nil;
        }
        #if __DEBUG_SKASHEK_ACTIONS
        "<.p>
        LURK: Starting creep...
        <.p>";
        #endif

        local decisionSelector = getRandomResult(6);
        //local decisionSelector = 5; // Test case
        if (decisionSelector <= 3) {
            suspendCreeping = true;
            return nil;
        }

        skashek.trapConnector(connector);

        creepingWithClicking = decisionSelector == 6;
        if (creepingWithClicking) {
            creepTurns = getRandomResult(6, 10);
        }
        else {
            creepTurns = 3;
            skashek.prepareSpeech();
            soundBleedCore.createSound(
                iKnowYoureInThereProfile,
                skashek,
                skashek.getOutermostRoom(),
                nil
            );
        }
        return true;
    }

    doSingleStep() {
        local oldRoom = skashek.getOutermostRoom();
        skashek.travelThroughComplex();
        local newRoom = skashek.getOutermostRoom();
        if (oldRoom != newRoom) {
            #if __DEBUG_SKASHEK_ACTIONS
            "<.p>
            LURK: Move into: <<newRoom.roomTitle>>";
            #endif
            if (currentStep == stepsInStride) {
                // Reset after move
                currentStep = 1;
            }
            else {
                // Drain boost
                currentStep--;
            }

            // Check temp goal first
            if (temporaryGoal != nil && newRoom == temporaryGoal) {
                suspendCreeping = nil;
                doorSlammedInFace = nil;
                temporaryGoal = nil;
                #if __DEBUG_SKASHEK_ACTIONS
                "\nTemporary goal reached!
                <.p>";
                #endif
                // Check if there is a chain of suspicion
                checkForSuspiciousDoors();
            }
            else if (soundGoal != nil && newRoom == soundGoal) {
                //TODO: If it's a sink, turn it off
                suspendCreeping = nil;
                doorSlammedInFace = nil;
                soundGoal = nil;
                lastSoundDistance = 1000;
                #if __DEBUG_SKASHEK_ACTIONS
                "\nSound source reached!";
                #endif
                // Check if there is a chain of suspicion
                checkForSuspiciousDoors();
                if (temporaryGoal == nil) {
                    inspectionTurns = getRandomResult(2, 4);
                    #if __DEBUG_SKASHEK_ACTIONS
                    "\nHanging out for <<inspectionTurns>> turns.";
                    #endif
                }
                #if __DEBUG_SKASHEK_ACTIONS
                "<.p>";
                #endif
            }
            // Check main goal
            else if (newRoom == goalRoom) {
                suspendCreeping = nil;
                doorSlammedInFace = nil;
                if (goalRoom == deliveryRoom &&
                    !skashek.hasSeenPreyOutsideOfDeliveryRoom
                ) {
                    #if __DEBUG_SKASHEK_ACTIONS
                    "\nDelivery Room reached!
                    \nDoing first-time inspection.";
                    #endif
                    skashek.checkDeliveryRoom();
                    inspectionTurns = 1;
                    #if __DEBUG_SKASHEK_ACTIONS
                    "<.p>";
                    #endif
                }
                else {
                    inspectionTurns = getRandomResult(3, 5);
                    #if __DEBUG_SKASHEK_ACTIONS
                    "\nGoal reached!
                    \nHanging out for <<inspectionTurns>> turns.
                    <.p>";
                    #endif
                }
            }
            #if __DEBUG_SKASHEK_ACTIONS
            "<.p>";
            #endif
        }
    }

    doSteps() {
        if (startCreeping()) return;
        if (huntCore.difficulty == nightmareMode) {
            // In nightmare mode, Skashek sprints all the time!
            doSingleStep();
            return;
        }
        // Steps oscillate between 1 and 2, where 2
        // is where movement actually takes place.
        // More bonus steps can be added for a speed boost.
        if (currentStep >= stepsInStride) {
            doSingleStep();
        }
        else {
            currentStep++;
        }
    }

    // If the player notices clicking, then creeping
    // becomes silent, and the player gets 3 turns to GTFO
    noticeOminousClicking() {
        if (suspendCreeping) return;
        creepingWithClicking = nil;
        creepTurns = 3;
    }

    doTurn() {
        checkForDoorMovingOnItsOwn();
        if (creepTurns > 0) {
            if (creepingWithClicking) {
                soundBleedCore.createSound(
                    ominousClickingProfile,
                    skashek,
                    skashek.getOutermostRoom(),
                    nil
                );
            }
            creepTurns--;
            if (creepTurns <= 0) {
                suspendCreeping = true;
                doorSlammedInFace = nil;
            }
            #if __DEBUG_SKASHEK_ACTIONS
            else {
                "<.p>
                LURK: Skashek is creeping!
                GTFO in <b><<creepTurns>> turns</b>, or less!
                <.p>";
            }
            #endif
        }
        else if (inspectionTurns > 0) {
            inspectionTurns--;
            if (inspectionTurns <= 0) {
                chooseNewRoom();
                currentStep = stepsInStride;
            }
        }
        else {
            checkForSuspiciousDoors();
            doSteps();
        }
    }

    checkForDoorMovingOnItsOwn() {
        local movingDoor = skashek.popDoorMovingOnItsOwn();
        if (movingDoor == nil) return nil;

        #if __DEBUG_SKASHEK_ACTIONS
        "<.p>
        LURK: <<movingDoor.theName>> is being weird!
        <.p>";
        #endif

        // If a door moves on its own, then drop everything
        // and go check it out!!
        inspectionTurns = 0;
        creepTurns = 0;
        changeCourseFor(
            movingDoor.otherSide.getOutermostRoom()
        );

        skashek.mockPreyForDoorMovement(
            movingDoor.getSoundSource()
        );

        return true;
    }

    checkForSuspiciousDoors() {
        // Stay up-to-date on suspicious moving doors
        if (checkForDoorMovingOnItsOwn()) return;

        // We already have a suspicious target
        if (temporaryGoal != nil) return;

        local suspiciousDoorsList =
            skashek.getOutermostRoom().getSuspiciousDoorsForSkashek();
        
        if (suspiciousDoorsList.length == 0) return;

        local skillCeiling = 6;

        //local skillRoll = skillCeiling; // Test case

        local skillRoll = getRandomResult(skillCeiling);
        if (huntCore.difficulty == nightmareMode ||
            suspiciousDoorsList.length == 1) {
            skillRoll = skillCeiling;
        }
        else {
            skillRoll = getRandomResult(skillCeiling);
        }

        local choiceIndex = 1;
        if (skillRoll == 1) return; // Ignores suspicious door
        if (skillRoll == 2) {
            // Sometimes Skashek will choose the wrong door.
            local mistakeSpan = 3;
            if (mistakeSpan > suspiciousDoorsList.length) {
                mistakeSpan = suspiciousDoorsList.length;
            }
            choiceIndex = getRandomResult(mistakeSpan);
        }

        local susDoor = suspiciousDoorsList[choiceIndex];

        skashek.mockPreyForDoorSuspicion(
            susDoor.getSoundSource()
        );

        changeCourseFor(
            susDoor.otherSide.getOutermostRoom()
        );
    }

    changeCourseFor(alternativeRoom) {
        skashek.hasSeenPreyOutsideOfDeliveryRoom = true;
        if (alternativeRoom == goalRoom) return;

        #if __DEBUG_SKASHEK_ACTIONS
        "<.p>
        LURK: Found something interesting!\n
        \t<<alternativeRoom.roomTitle>>
        <.p>";
        #endif

        temporaryGoal = alternativeRoom;
        addSpeedBoost(3);
    }

    followSound(impact) {
        skashek.hasSeenPreyOutsideOfDeliveryRoom = true;

        local source = impact.sourceOrigin;
        local alternativeRoom = source.getOutermostRoom();
        local soundWasDoor = nil;
        if (source.ofKind(Door)) {
            soundWasDoor = true;
            if (alternativeRoom.ofKind(HallwaySegment)) {
                source = source.otherSide;
                alternativeRoom = source.getOutermostRoom();
            }
        }

        // If we were already heading there, then nevermind
        if (alternativeRoom == goalRoom) return;
        if (
            soundWasDoor && 
            (source.getOutermostRoom() == goalRoom ||
            source.otherSide.getOutermostRoom() == goalRoom)
        ) return;

        // If we were already heading there too, then nevermind
        if (alternativeRoom == temporaryGoal) return;
        if (
            soundWasDoor && 
            (source.getOutermostRoom() == temporaryGoal ||
            source.otherSide.getOutermostRoom() == temporaryGoal)
        ) return;

        local mapModeAlt = alternativeRoom.mapModeVersion;
        if (mapModeAlt == nil) return;
        local path = skashek.getFullPathToMapModeRoom(mapModeAlt);

        if (path == nil) return;
        if (path.length == 1) return;
        local dist = path.length - 1;

        if (dist >= lastSoundDistance) return;

        #if __DEBUG_SKASHEK_ACTIONS
        "<.p>
        LURK: Heard something interesting!\n
        \t<<alternativeRoom.roomTitle>>
        <.p>";
        #endif

        if (soundWasDoor && temporaryGoal == nil) {
            if (getRandomResult(3) > 1) {
                if (impact.soundProfile == doorSuspiciousSilenceProfile) {
                    skashek.mockPreyForDoorAlteration(
                        source.getSoundSource()
                    );
                }
                else {
                    skashek.mockPreyForDoorClosing(
                        source.getSoundSource(),
                        alternativeRoom
                    );
                }
            }
        }
        
        soundGoal = alternativeRoom;
        lastSoundDistance = dist;
    }

    onSightAfter(begins) {
        if (skashek.playerLeewayTurns > 0) {
            if (begins && skashek.playerLeewayTurns <
                huntCore.difficultySettingObj.turnsBeforeSkashekDeploys
            ) {
                "<.p><q>Prey, I'm giving you quite the
                opportunity here! I suggest you run <i>far
                away</i> from me!</q> <<getPeekHe()>> says, smiling. ";
            }
            skashek.playerLeewayTurns--;
            if (skashek.playerLeewayTurns == 0) {
                leewayExpired = true;
            }
            return;
        }
        if (leewayExpired) {
            leewayExpired = nil;
            "<.p><q>My mercy has expired, Prey!</q> <<getPeekHe()>> shouts.
            <q>Run for your fucking <i>life!!</i></q><.p>";
        }
        else {
            if (!begins) return;
            if (!skashek.didAnnouncementDuringTurn) {
                "<.p><q>Aha!</q> <<getPeekHe()>> shouts.
                <q><i>There</i> you are!</q><.p>";
            }
        }
        skashekChaseState.activate();
    }

    describeNonTravelAction() {
        "<<getPeekHeIs(true)>> looking around
        <<skashek.getOutermostRoom.roomTitle>>{dummy} for {me}! ";
    }
}