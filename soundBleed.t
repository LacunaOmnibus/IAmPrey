enum bleedSource, wallMuffle, closeEcho, distantEcho;

soundBleedCore: object {
    soundDaemon = nil
    freshBlood = static new Vector(10) // Newly-spawned sound bleeds go here

    selectedDirection = nil
    selectedConnector = nil
    selectedDestination = nil
    selectedMuffleDestination = nil

    activate() {
        soundDaemon = new Daemon(self, &doBleed, 0);
        soundDaemon.eventOrder = 110;
    }

    createSound(soundProfile, room) {
        local _freshBlood = new SoundBlood(soundProfile, room);
        freshBlood.append(_freshBlood);
    }

    doBleed() {
        if (freshBlood.length == 0) return;

        for (local i = 1; i <= freshBlood.length; i++) {
            doBleedFor(freshBlood[i]);
        }

        freshBlood.removeRange(1, -1);
    }

    doBleedFor(currentBlood) {
        currentBlood.soundProfile.playerPerceivedStrength = 0;
        currentBlood.soundProfile.hunterHeard = nil;
        propagateRoom(currentBlood.room, currentBlood.soundProfile, bleedSource, 3, nil);
    }

    propagateRoom(room, profile, form, strength, sourceDirection) {
        // If sourceDirection is nil, we are in the source room.

        //TODO: Test for hunter

        if (room == gPlayerChar.getOutermostRoom()) {
            // No reason for the player to hear themselves
            if (!profile.isFromPlayer) {
                // Only reveal to the player if it wasn't heard louder before
                if (profile.playerPerceivedStrength < strength) {
                    profile.playerPerceivedStrength = strength;

                    local throughDoor = nil;
                    if (sourceDirection != nil) {
                        local sourceConnector = room.(sourceDirection.dirProp);
                        if (sourceConnector != nil) {
                            throughDoor = sourceConnector.isOpenable;
                        }
                    }

                    //Debug only:
                    say('\n' + profile.getReportString(form, sourceDirection, throughDoor));
                }
            }
        }

        if (strength == 1) return;

        local priorityFlag = nil;

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
                        propagateRoom(selectedMuffleDestination, profile, wallMuffle, 1, nextSourceDir);
                        priorityFlag = true; // Gets priority.
                    }
                }
            }
        }

        if (priorityFlag) return;

        if (strength >= 2) {
            // Muffle through closed doors propagation
            for (local i = 1; i <= 12; i++) {
                room.selectSoundDirection(i);
                if (selectedDestination != nil) {
                    local nextSourceDir = selectedDestination.getDirectionTo(room);
                    if (nextSourceDir != nil) {
                        if (selectedConnector.isOpenable) {
                            if (!selectedConnector.isOpen) {
                                propagateRoom(selectedDestination, profile, wallMuffle, 1, nextSourceDir);
                                priorityFlag = true; // Gets priority.
                            }
                        }
                    }
                }
            }
        }

        if (priorityFlag) return;

        // Echo propagation
        for (local i = 1; i <= 12; i++) {
            room.selectSoundDirection(i);
            if (selectedDestination != nil) {
                local nextSourceDir = selectedDestination.getDirectionTo(room);
                if (nextSourceDir != nil) {
                    local nextStrength = strength - 1;
                    local nextForm = (nextStrength == 2) ? closeEcho : distantEcho;
                    propagateRoom(selectedDestination, profile, nextForm, nextStrength, nextSourceDir);
                }
            }
        }
    }
}

//TODO: Ability to dispense temporary Sound objects into the player's room,
// in case they use the LISTEN command, and there's information worth putting there.
class SoundProfile: object {
    construct(_muffledStr, _closeEchoStr, _distantEchoStr, _isFromPlayer?) {
        muffledStr = _muffledStr;
        closeEchoStr = _closeEchoStr;
        distantEchoStr = _distantEchoStr;
        isFromPlayer = _isFromPlayer;
    }

    muffledStr = 'the muffled sound of a mysterious noise'
    closeEchoStr = 'the nearby echo of a mysterious noise'
    distantEchoStr = 'the distant echo of a mysterious noise'
    isFromPlayer = nil

    playerPerceivedStrength = 0
    hunterHeard = nil

    getReportString(form, direction, throughDoor) {
        local dirTitle = 'the ' + direction.name;
        if (direction == upDir) dirTitle = 'above';
        if (direction == downDir) dirTitle = 'below';
        if (direction == inDir) dirTitle = 'inside';
        if (direction == outDir) dirTitle = 'outside';

        local routeSetup = throughDoor ? 'Through a doorway to ' : 'From ';

        if (form == wallMuffle) {
            routeSetup = throughDoor ? 'Through a closed door to ' : 'Through a wall to ';
            return routeSetup + dirTitle +
                ', you hear ' + muffledStr + '. ';
        }
        
        return routeSetup + dirTitle +
            ', you hear ' + (form == closeEcho ? closeEchoStr : distantEchoStr) + '. ';
    }
}

class SoundBlood: object {
    construct(_soundProfile, _room) {
        soundProfile = _soundProfile;
        room = _room;
    }

    soundProfile = nil
    room = nil
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