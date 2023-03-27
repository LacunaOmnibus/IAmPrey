assemblyShop: Room { 'The Assembly Shop'
    "TODO: Add description.\b
    A CNC machine sits in the southeast corner of the room.
    Far above it, on the east wall, {i} see a vent.\b
    A doorway to the Common Room is to the <<hyperDir('south')>>,
    while the exit door is to the <<hyperDir('north')>>. "

    south = commonRoom

    eastMuffle = lifeSupportTop
    westMuffle = directorsOffice

    mapModeDirections = [&north, &south]
    familiar = roomsFamiliarByDefault
}

+cncMachine: FixedPlatform { 'the CNC machine;drill;table'
    "A large table, with a drill-like machine, which moves around the table on
    a translating frame. It's used to cut precise shapes out of wood and metal. "

    noControlsMsg = 
        '<<gSkashekName>> has locked the controls to this machine. '

    dobjFor(SwitchOn) {
        verify() {
            inaccessible(noControlsMsg);
        }
    }

    dobjFor(SwitchOff) {
        verify() {
            inaccessible(noControlsMsg);
        }
    }

    dobjFor(SwitchVague) {
        verify() {
            inaccessible(noControlsMsg);
        }
    }
}
++LowFloorHeight;

DefineDoorNorthTo(northHall, assemblyShop, 'the Assembly Shop door')