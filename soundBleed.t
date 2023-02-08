enum bleedSource, wallMuffle, closeEcho, distantEcho;
#define gThroughDoorPriority 3

#define __DEBUG_SOUND_PLAYER_SIDE nil
#define __SHOW_EMISSION_STARTS nil

soundBleedCore: object {
    envSoundEmissions = static new Vector(16)
    playerSoundEmissions = static new Vector(16)

    propagatedRooms = static new Vector(64)

    activeSubtleSounds = static new Vector(16)

    selectedDirection = nil
    selectedConnector = nil
    selectedDestination = nil
    selectedMuffleDestination = nil

    goalRoom = nil

    propagationPerceivedStrength = 0

    currentSoundImpact = nil

    addEmission(vec, soundProfile, soundSource, room) {
        for (local i = 1; i <= vec.length; i++) {
            if (vec[i].isIdenticalToStart(
                soundProfile, soundSource, room)) {
                return;
            }
        }
        vec.append(new SoundImpact(
            soundProfile,
            soundSource,
            room
        ));
    }

    createSound(soundProfile, emitter, room, causedByPlayer) {
        local soundSource = emitter.getSoundSource();
        addEmission(
            causedByPlayer ? playerSoundEmissions : envSoundEmissions,
            soundProfile,
            soundSource,
            room
        );
    }

    doPropagation() {
        for (local i = 1; i <= activeSubtleSounds.length; i++) {
            activeSubtleSounds[i].checkLifecycle();
        }

        if (envSoundEmissions.length == 0 && playerSoundEmissions.length == 0) return;
        
        if (envSoundEmissions.length > 0) {
            for (local i = 1; i <= envSoundEmissions.length; i++) {
                local emission = envSoundEmissions[i];
                #if __SHOW_EMISSION_STARTS
                emission.soundProfile.afterEmission(emission.sourceLocation);
                #endif
                currentSoundImpact = emission;
                doPropagationForPlayer(emission.soundProfile, emission.sourceLocation);
            }
            envSoundEmissions.removeRange(1, -1);
            gPlayerChar.doPerception();
        }

        if (playerSoundEmissions.length > 0) {
            for (local i = 1; i <= playerSoundEmissions.length; i++) {
                local emission = playerSoundEmissions[i];
                #if __SHOW_EMISSION_STARTS
                emission.afterEmission(emission.sourceLocation);
                #endif
                currentSoundImpact = emission;
                doPropagationForSkashek(emission.soundProfile, emission.sourceLocation);
            }
            playerSoundEmissions.removeRange(1, -1);
            skashek.doPerception();
        }
    }

    doPropagationForPlayer(soundProfile, startRoom) {
        goalRoom = gPlayerChar.getOutermostRoom();
        // If the sound comes from the same room that the player is in,
        // then we should have provided this sound directly by now.
        if (startRoom == gPlayerChar.getOutermostRoom()) return;
        
        propagationPerceivedStrength = 0;
        #if __DEBUG_SOUND_PLAYER_SIDE
        "<.p>(Propagating into <<startRoom.roomTitle>>)<.p>";
        #endif
        propagateRoomForPlayer(startRoom, soundProfile, bleedSource, 3, nil);
        clearRooms();
    }

    doPropagationForSkashek(soundProfile, startRoom) {
        goalRoom = skashek.getOutermostRoom();
        propagateRoomForSkashek(startRoom, soundProfile, soundProfile.strength, nil);
        clearRooms();
    }

    checkPropagationStep(room, strength) {
        if (room.highestSoundStrength < strength) {
            room.highestSoundStrength = strength;
            propagatedRooms.appendUnique(room);
            return true;
        }

        return nil;
    }

    clearRooms() {
        if (propagatedRooms.length == 0) return;

        for (local i = 1; i <= propagatedRooms.length; i++) {
            propagatedRooms[i].highestSoundStrength = 0;
        }

        propagatedRooms.removeRange(1, -1);
    }

    propagateRoomForPlayer(room, profile, form, strength, sourceDirection) {
        if (room == goalRoom) {
            #if __DEBUG_SOUND_PLAYER_SIDE
            "<.p>(Found player in <<room.roomTitle>>)<.p>";
            #endif
            // Only reveal to the player if it wasn't heard louder before
            if (propagationPerceivedStrength < strength) {
                propagationPerceivedStrength = strength;

                local throughDoor = nil;
                if (sourceDirection != nil) {
                    local sourceConnector = room.(sourceDirection.dirProp);
                    if (sourceConnector != nil) {
                        throughDoor = sourceConnector.isOpenable;
                    }
                }

                currentSoundImpact.sourceDirection = sourceDirection;
                currentSoundImpact.form = form;
                currentSoundImpact.throughDoor = throughDoor;
                currentSoundImpact.strength = strength;
                currentSoundImpact.priority = getPriorityFromForm(form, throughDoor);
                gPlayerChar.addSoundImpact(currentSoundImpact, &priority);
            }
            // It doesn't matter if we were accepted; we just got there
            return;
        }

        if (strength <= 1) return;

        if (strength == 3) {
            // Muffle through walls propagation
            for (local i = 1; i <= 12; i++) {
                room.selectSoundDirection(i);
                if (selectedMuffleDestination != nil) {
                    local nextSourceDir = selectedMuffleDestination.getMuffleDirectionTo(room);
                    // If we can send the sound through a wall, then prioritize that.
                    // The only other way it could arrive would be a distant echo (2 rooms away),
                    // which would have the same strength, but has less priority.
                    if (nextSourceDir != nil) {
                        // We are faking strengths:
                        // 1 = distant echo
                        // 2 = through wall
                        // 3 = through closed door
                        // 4 = close echo
                        // 5 = source
                        if (!checkPropagationStep(selectedMuffleDestination, 2)) continue;
                        
                        #if __DEBUG_SOUND_PLAYER_SIDE
                        "<.p>(Muffling into <<selectedMuffleDestination.roomTitle>>)<.p>";
                        #endif

                        propagateRoomForPlayer(selectedMuffleDestination, profile, wallMuffle, 1, nextSourceDir);
                    }
                }
            }
        }

        if (strength >= 2) {
            // Muffle through closed doors propagation
            for (local i = 1; i <= 12; i++) {
                room.selectSoundDirection(i);
                if (selectedDestination != nil) {
                    local nextSourceDir = selectedDestination.getDirectionTo(room);
                    if (nextSourceDir != nil) {
                        if (selectedConnector.isOpenable) {
                            if (!selectedConnector.isOpen) {
                                if (!checkPropagationStep(selectedDestination, 3)) continue;

                                #if __DEBUG_SOUND_PLAYER_SIDE
                                "<.p>(Door-muffling into <<selectedDestination.roomTitle>>)<.p>";
                                #endif
                                
                                propagateRoomForPlayer(selectedDestination, profile, wallMuffle, 1, nextSourceDir);
                            }
                        }
                    }
                }
            }
        }

        // Echo propagation
        for (local i = 1; i <= 12; i++) {
            room.selectSoundDirection(i);
            if (selectedDestination != nil) {
                local nextSourceDir = selectedDestination.getDirectionTo(room);
                if (nextSourceDir != nil) {
                    local nextStrength = strength - 1;
                    local fakeNextStrength = nextStrength;
                    if (fakeNextStrength > 1) fakeNextStrength += 2;

                    if (!checkPropagationStep(selectedDestination, fakeNextStrength)) continue;

                    #if __DEBUG_SOUND_PLAYER_SIDE
                    "<.p>(Echoing into <<selectedDestination.roomTitle>>)<.p>";
                    #endif

                    local nextForm = (nextStrength == 2) ? closeEcho : distantEcho;
                    propagateRoomForPlayer(selectedDestination, profile, nextForm, nextStrength, nextSourceDir);
                }
            }
        }
    }

    propagateRoomForSkashek(room, profile, strength, sourceDirection) {
        if (room == goalRoom) {
            // Only reveal to Skashek if it wasn't heard louder before
            if (propagationPerceivedStrength < strength) {
                propagationPerceivedStrength = strength;

                currentSoundImpact.strength = strength;
                skashek.addSoundImpact(currentSoundImpact, &strength);
            }
            // It doesn't matter if we were accepted; we just got there
            return;
        }

        if (strength <= 1) return;
        for (local i = 1; i <= 12; i++) {
            room.selectSoundDirection(i);

            local nextStrength = strength - 2;

            if (selectedMuffleDestination != nil && strength > 2) {
                local nextSourceDir = selectedMuffleDestination.getMuffleDirectionTo(room);
                if (nextSourceDir != nil) {
                    if (!checkPropagationStep(selectedMuffleDestination, nextStrength)) continue;

                    propagateRoomForSkashek(selectedMuffleDestination, profile, nextStrength, nextSourceDir);
                }
            }

            if (selectedDestination != nil) {
                local nextSourceDir = selectedDestination.getDirectionTo(room);
                if (nextSourceDir != nil) {
                    local falloff = 1;

                    if (selectedConnector.isOpenable) {
                        if (!selectedConnector.isOpen) {
                            falloff = 2;
                            if (strength <= falloff) continue;
                        }
                    }

                    nextStrength = strength - falloff;

                    if (!checkPropagationStep(selectedDestination, nextStrength)) continue;

                    propagateRoomForSkashek(selectedDestination, profile, nextStrength, nextSourceDir);
                }
            }
        }
    }

    getDirIndexFromDir(dir) {
        switch (dir) {
            default:
                return nil;
            case northDir:
                return 1;
            case northeastDir:
                return 2;
            case eastDir:
                return 3;
            case southeastDir:
                return 4;
            case southDir:
                return 5;
            case southwestDir:
                return 6;
            case westDir:
                return 7;
            case northwestDir:
                return 8;
            case upDir:
                return 9;
            case downDir:
                return 10;
            case inDir:
                return 11;
            case outDir:
                return 12;
        }
    }

    // PRIORITIES:
    // Source       = 5
    // Wall muffle  = 4
    // Door muffle  = 3
    // Close echo   = 2
    // Distant echo = 1
    // Nothing      = 0

    getPriorityFromForm(form, throughDoor) {
        switch (form) {
            default:
                return 0;
            case distantEcho:
                return 1;
            case wallMuffle:
                return throughDoor ? gThroughDoorPriority : 4;
            case closeEcho:
                return 2;
            case bleedSource:
                return 5;
        }
    }

    getFormFromPriority(priority) {
        switch (priority) {
            default:
                return nil;
            case 1:
                return distantEcho;
            case 4:
            case gThroughDoorPriority:
                return wallMuffle;
            case 2:
                return closeEcho;
            case 5:
                return bleedSource;
        }
    }

    getReportStringHeader(form, sourceDirection, throughDoor) {
        local dirTitle = 'the ' + sourceDirection.name;
        if (sourceDirection == upDir) dirTitle = 'above';
        if (sourceDirection == downDir) dirTitle = 'below';
        if (sourceDirection == inDir) dirTitle = 'inside';
        if (sourceDirection == outDir) dirTitle = 'outside';

        local routeSetup = throughDoor ? 'Through a doorway to ' : 'From ';

        if (form == wallMuffle) {
            routeSetup = throughDoor ? 'Through a closed door to ' : 'Through a wall to ';
        }
        
        return routeSetup + dirTitle + ', you hear ';
    }
}

modify Thing {
    // Returns the representative of sounds we cause
    getSoundSource() {
        return self;
    }
}

modify Door {
    soundSourceRepresentative = nil

    preinitThing() {
        inherited();

        // Arbitrarily agree on a source representative
        if (otherSide != nil) {
            if (otherSide.soundSourceRepresentative != nil) {
                // otherSide has already made its decision
                // so we must play along
                soundSourceRepresentative =
                    otherSide.soundSourceRepresentative;
            }
            else {
                // otherSide has not yet decided,
                // so we take charge
                soundSourceRepresentative = self;
                otherSide.soundSourceRepresentative = self;
            }
        }
        else {
            // There is no otherSide.
            // Anarchy in Adv3Lite!
            soundSourceRepresentative = self;
        }
    }

    getSoundSource() {
        return soundSourceRepresentative;
    }
}

// Used for sorting and prioritizing sound perceptions
class SoundImpact: object {
    construct(soundProfile_, sourceOrigin_, sourceLocation_) {
        soundProfile = soundProfile_;
        sourceOrigin = sourceOrigin_;
        sourceLocation = sourceLocation_;
    }

    soundProfile = nil
    form = nil
    sourceOrigin = nil
    sourceLocation = nil
    sourceDirection = nil
    throughDoor = nil
    strength = 0
    priority = 0

    isIdenticalToStart(soundProfile_, sourceOrigin_, sourceLocation_) {
        if (soundProfile != soundProfile_) return nil;
        if (sourceOrigin != sourceOrigin_) return nil;
        if (sourceLocation != sourceLocation_) return nil;
        return true;
    }

    isIdenticalToImpact(otherImpact) {
        if (soundProfile != otherImpact.soundProfile) return nil;
        if (sourceOrigin != otherImpact.sourceOrigin) return nil;
        return true;
    }
}

modify Actor {
    perceivedSoundImpacts = perInstance(new Vector(16))

    addSoundImpact(impact, sortProp) {
        for (local i = 1; i <= perceivedSoundImpacts.length; i++) {
            local otherImpact = perceivedSoundImpacts[i];
            // We are only interested in matches
            if (!impact.isIdenticalToImpact(otherImpact)) continue;
            // Another one is already handling it better
            if (impact.(sortProp) <= otherImpact.(sortProp)) return;
            // We could handle it better
            perceivedSoundImpacts[i] = impact;

            #if __SHOW_EMISSION_STARTS
            "<.p><<theName>> heard that better!<.p>";
            #endif

            return;
        }

        // No conflicts at all; add it
        perceivedSoundImpacts.append(impact);
        #if __SHOW_EMISSION_STARTS
        "<.p><<theName>> heard that.<.p>";
        #endif
    }

    doPerception() {
        if (gPlayerChar == self) {
            doPlayerPerception();
        }
        if (perceivedSoundImpacts.length > 0) {
            perceivedSoundImpacts.removeRange(1, -1);
        }
    }

    doPlayerPerception() {
        #if __SHOW_EMISSION_STARTS
        "<.p><<theName>>.perceivedSoundImpacts: <<perceivedSoundImpacts.length>><.p>";
        #endif
        // Try simple stuff first...
        if (perceivedSoundImpacts.length == 0) return;
        say('<.p>');
        if (perceivedSoundImpacts.length == 1) {
            local impact = perceivedSoundImpacts[1];
            if (impact.soundProfile.isSuspicious) {
                impact.soundProfile.lastSuspicionTarget = impact.sourceOrigin;
            }
            impact.soundProfile.doPlayerPerception(
                impact.form,
                impact.sourceDirection,
                impact.throughDoor
            );
            return;
        }

        // Otherwise, sort stuff...

        // Prepare to group stuff by direction
        local impactsByDir = new Vector(12);
        local formsByDir = new Vector(12);
        local miscImpacts = new Vector(3);

        // Initialize vectors
        for (local i = 1; i <= 12; i++) {
            impactsByDir.append(nil);
            formsByDir.append(0);
        }

        // Sort
        for (local i = 1; i <= perceivedSoundImpacts.length; i++) {
            local impact = perceivedSoundImpacts[i];

            // Subtle sounds have thing-based handling,
            // so we handle these individually.
            if (impact.soundProfile.subtleSound != nil) {
                impact.soundProfile.subtleSound.perceiveIn(
                    gPlayerChar.getOutermostRoom(),
                    impact.soundProfile.getReportString(
                        impact.form,
                        impact.sourceDirection,
                        impact.throughDoor
                    )
                );
                continue;
            }

            // If requested, we will show these alone
            if (impact.soundProfile.isSuspicious) {
                impact.soundProfile.lastSuspicionTarget = impact.sourceOrigin;
                impact.soundProfile.doPlayerPerception(
                    impact.form, impact.sourceDirection, impact.throughDoor
                );
                continue;
            }

            local formPriority =
                soundBleedCore.getPriorityFromForm(impact.form, impact.throughDoor);

            if (formPriority == 0 || formPriority == 5) {
                // We shouldn't be handling these here
                continue;
            }

            local dirIndex =
                soundBleedCore.getDirIndexFromDir(impact.sourceDirection);

            if (dirIndex == nil) {
                miscImpacts.append(impact);
                continue;
            }

            local dirVec = impactsByDir[dirIndex];
            if (dirVec == nil) {
                dirVec = new Vector(3);
                impactsByDir[dirIndex] = dirVec;
            }
            dirVec.append(impact);

            if (formPriority > formsByDir[dirIndex]) {
                formsByDir[dirIndex] = formPriority;
            }
        }

        // Build
        for (local i = 1; i <= 12; i++) {
            local dirVec = impactsByDir[i];
            if (dirVec == nil) continue;

            if (dirVec.length == 1) {
                local impact = dirVec[1];
                impact.soundProfile.doPlayerPerception(
                    impact.form,
                    impact.sourceDirection,
                    impact.throughDoor
                );
                continue;
            }

            // Setup group...
            local strBfr = new StringBuffer((dirVec.length + 2)*2);
            local sourceDirection = dirVec[1].sourceDirection;
            local priority = formsByDir[i];
            local form = soundBleedCore.getFormFromPriority(priority);
            local throughDoor = priority == gThroughDoorPriority;
            strBfr.append(soundBleedCore.getReportStringHeader(
                form, sourceDirection, throughDoor
            ));

            for (local j = 1; j <= dirVec.length; j++) {
                local impact = dirVec[j];
                local descString = impact.soundProfile.getDescString(form);
                strBfr.append(descString);
                if (j == dirVec.length - 1) {
                    strBfr.append(', and ');
                }
                else if (j < dirVec.length - 1) {
                    strBfr.append(', ');
                }
            }

            strBfr.append('.');

            say(toString(strBfr));
        }
    }
}

SoundProfile template 'muffledStr' 'closeEchoStr' 'distantEchoStr';

class SoundProfile: object {
    strength = 3
    muffledStr = 'the muffled sound of a mysterious noise'
    closeEchoStr = 'the nearby echo of a mysterious noise'
    distantEchoStr = 'the distant echo of a mysterious noise'
    subtleSound = nil
    isSuspicious = nil
    lastSuspicionTarget = nil
    absoluteDesc = nil

    doPlayerPerception(form, sourceDirection, throughDoor) {
        local reportStr = getReportString(form, sourceDirection, throughDoor);
        if (subtleSound == nil) {
            // Direct perception
            say('\n' + reportStr);
        }
        else {
            // LISTEN perception only
            subtleSound.perceiveIn(gPlayerChar.getOutermostRoom(), reportStr);
        }
    }

    getReportString(form, sourceDirection, throughDoor) {
        if (absoluteDesc) {
            return getDescString(form);
        }
        local dirTitle = 'the ' + sourceDirection.name;
        if (sourceDirection == upDir) dirTitle = 'above';
        if (sourceDirection == downDir) dirTitle = 'below';
        if (sourceDirection == inDir) dirTitle = 'inside';
        if (sourceDirection == outDir) dirTitle = 'outside';

        local routeSetup = throughDoor ? 'Through a doorway to ' : 'From ';

        if (form == wallMuffle) {
            routeSetup = throughDoor ? 'Through a closed door to ' : 'Through a wall to ';
            return routeSetup + dirTitle +
                ', you hear ' + muffledStr + (isSuspicious ? ' ' : '. ');
        }
        
        return routeSetup + dirTitle +
            ', you hear ' + (form == closeEcho ? closeEchoStr : distantEchoStr) + (isSuspicious ? ' ' : '. ');
    }

    getDescString(form) {
        switch (form) {
            case wallMuffle:
                return muffledStr;
            case closeEcho:
                return closeEchoStr;
            default:
                return distantEchoStr;
        }
    }

    afterEmission(room) {
        // For debug purposes.
    }
}

SubtleSound template 'basicName' 'missedMsg'?;

class SubtleSound: Noise {
    construct() {
        vocab = basicName + ';muffled distant nearby;echo';
        if (location != nil) {
            if (location.ofKind(SoundProfile)) {
                location.subtleSound = self;
            }
            location = nil;
        }
        soundBleedCore.activeSubtleSounds.append(self);
        inherited();
    }
    desc() {
        attemptPerception();
    }
    listenDesc() {
        attemptPerception();
    }

    basicName = 'mysterious noise'
    caughtMsg = '{I} hear{s/d} a mysterious sound. ' // Automatically generated
    missedMsg = 'The sound seems to have stopped. ' // Author-made

    wasPerceived = nil

    lifecycleFuse = nil
    isBroadcasting = nil

    doAfterPerception() {
        // For setting off actions based on player observation
    }

    perceiveIn(room, _caughtMsg) {
        moveInto(room);
        caughtMsg = _caughtMsg;
        wasPerceived = nil;
        isBroadcasting = true;
    }

    attemptPerception() {
        if (wasPerceived) {
            say(missedMsg);
            doAfterPerception();
            endLifecycle();
        }
        else {
            say(caughtMsg);
            wasPerceived = true;
        }
    }

    checkLifecycle() {
        if (!isBroadcasting) return;
        if (!wasPerceived) {
            endLifecycle();
        }
        isBroadcasting = nil;
    }

    endLifecycle() {
        moveInto(nil);
    }
}

#define selectSoundDirectionExp(i, dir) \
    case i: \
        soundBleedCore.selectedDirection = dir##Dir; \
        soundBleedCore.selectedDestination = nil; \
        soundBleedCore.selectedConnector = getConnector(&##dir); \
        soundBleedCore.selectedMuffleDestination = dir##Muffle; \
        break

#define searchMuffleDirection(dir) if (dir##Muffle == dest) { return dir##Dir; }

modify Room {
    // A room can be assigned to any of these to create a muffling wall connection
    northMuffle = nil     // 1
    northeastMuffle = nil // 2
    eastMuffle = nil      // 3
    southeastMuffle = nil // 4
    southMuffle = nil     // 5
    southwestMuffle = nil // 6
    westMuffle = nil      // 7
    northwestMuffle = nil // 8
    upMuffle = nil        // 9
    downMuffle = nil      // 10
    inMuffle = nil        // 11
    outMuffle = nil       // 12

    highestSoundStrength = 0

    getMuffleDirectionTo(dest) {
        searchMuffleDirection(north);
        searchMuffleDirection(northeast);
        searchMuffleDirection(east);
        searchMuffleDirection(southeast);
        searchMuffleDirection(south);
        searchMuffleDirection(southwest);
        searchMuffleDirection(west);
        searchMuffleDirection(northwest);
        searchMuffleDirection(up);
        searchMuffleDirection(down);
        searchMuffleDirection(in);
        searchMuffleDirection(out);
        return nil;
    }

    selectSoundDirection(dirIndex) {
        switch (dirIndex) {
            selectSoundDirectionExp(1, north);
            selectSoundDirectionExp(2, northeast);
            selectSoundDirectionExp(3, east);
            selectSoundDirectionExp(4, southeast);
            selectSoundDirectionExp(5, south);
            selectSoundDirectionExp(6, southwest);
            selectSoundDirectionExp(7, west);
            selectSoundDirectionExp(8, northwest);
            selectSoundDirectionExp(9, up);
            selectSoundDirectionExp(10, down);
            selectSoundDirectionExp(11, in);
            selectSoundDirectionExp(12, out);
        }

        if (soundBleedCore.selectedConnector != nil) {
            soundBleedCore.selectedDestination = soundBleedCore.selectedConnector.destination();
        }
    }
}