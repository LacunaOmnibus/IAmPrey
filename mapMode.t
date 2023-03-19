// Lmao, we going DEEP, bois!
// Intercept any action execution and suspend it,
// if it's not valid for map mode.
// Intercepting it waaaayyyyy out here, because
// this cannot afford to be modified by any other shenanigans.
modify Command {
    exec() {
        if (mapModeDatabase.inMapMode && !action.isAllowedInMapMode) {
            mapModeDatabase.cancelNonMapAction();
        }
        else {
            inherited();
        }
    }
}

modify Action {
    isAllowedInMapMode = nil
}

modify SystemAction {
    isAllowedInMapMode = true
}

VerbRule(ToggleMapMode)
    ('toggle'|'switch'|) 'map' ('mode'|)
    : VerbProduction
    action = ToggleMapMode
    verbPhrase = 'toggle/toggling map mode'
;

DefineSystemAction(ToggleMapMode)
    execAction(cmd) {
        if (mapModeDatabase.inMapMode) {
            mapModeDatabase.mapModeOff();
        }
        else {
            mapModeDatabase.mapModeOn();
        }
    }
    turnsTaken = 0
;

VerbRule(SetMapModeOn)
    ('set'|'turn'|) 'map' ('mode'|) 'on' |
    ('open'|'enter') 'map' ('mode'|)
    : VerbProduction
    action = SetMapModeOn
    verbPhrase = 'set/setting map mode on'
;

DefineSystemAction(SetMapModeOn)
    execAction(cmd) {
        if (mapModeDatabase.inMapMode) {
            "You are already in map mode. ";
            exit;
        }
        else {
            mapModeDatabase.mapModeOn();
        }
    }
    turnsTaken = 0
;

VerbRule(SetMapModeOff)
    ('set'|'turn'|) 'map' ('mode'|) 'off' |
    ('close'|'exit'|'leave'|'get' 'out' 'of') 'map' ('mode'|)
    : VerbProduction
    action = SetMapModeOff
    verbPhrase = 'set/setting map mode off'
;

DefineSystemAction(SetMapModeOff)
    execAction(cmd) {
        if (mapModeDatabase.inMapMode) {
            mapModeDatabase.mapModeOff();
        }
        else {
            "You are not in map mode. ";
            exit;
        }
    }
    turnsTaken = 0
;

VerbRule(RecenterMap)
    'home' |
    ('center'|'recenter') 'map'
    : VerbProduction
    action = RecenterMap
    verbPhrase = 'recenter/recentering map'
;

DefineSystemAction(RecenterMap)
    execAction(cmd) {
        if (mapModeDatabase.inMapMode) {
            mapModePlayer.moveInto(mapModeStart);
            mapModeStart.lookAroundWithin();
        }
        else {
            "You are not in map mode. ";
            exit;
        }
    }
    turnsTaken = 0
;

VerbRule(MapModeCompass)
    ('check'|) ('compass'|'directions') |
    'where' 'to' ('next'|) |
    'next' ('direction'|'way')
    : VerbProduction
    action = MapModeCompass
    verbPhrase = 'check/checking compass'
;

DefineSystemAction(MapModeCompass)
    execAction(cmd) {
        mapModeDatabase.checkCompass();
    }
    turnsTaken = 0
;

modify VerbRule(GoTo)
    ('go' 'to'|'goto'|'walk' 'to'|('plot'|'set') 'route' 'to'|
    'set' 'compass' ('to'|'for')|'set' 'goal' ('as'|)|'goal')
    singleDobj
    :
;

modify GoTo {
    turnsTaken = 0
    isAllowedInMapMode = true

    execAction(cmd) {
        if (gDobj == nil) {
            say(mapModeDatabase.notOnMapMsg);
            exit;
        }
        else {
            mapModeDatabase.setGoto(gDobj);
        }
    }
}

modify Continue {
    turnsTaken = 0
    isAllowedInMapMode = true
    
    exec(cmd) {
        MapModeCompass.exec(cmd);
    }
}

modify Look {
    isAllowedInMapMode = true
}

modify Examine {
    isAllowedInMapMode = true
}

modify ExamineOrGoTo {
    isAllowedInMapMode = true
}

modify TravelAction {
    isAllowedInMapMode = true
}

modify Wait {
    isAllowedInMapMode = true
    exec(cmd) {
        if (mapModeDatabase.inMapMode) {
            "Time does not pass in map mode. ";
            exit;
        }
        else {
            inherited(cmd);
        }
    }
}

modify ShowParkourRoutes {
    isAllowedInMapMode = nil
}

modify ShowParkourLocalPlatforms {
    isAllowedInMapMode = nil
}

modify ShowAllParkourRoutes {
    isAllowedInMapMode = nil
}

modify PeekDirection {
    isAllowedInMapMode = nil
}

modify SneakDirection {
    isAllowedInMapMode = nil
}

modify ChangeSneakMode {
    isAllowedInMapMode = nil
}

#ifdef __DEBUG
VerbRule(DumpRouteTable)
    'dump' 'route' 'table'
    : VerbProduction
    action = DumpRouteTable
    verbPhrase = 'dump/dumping route table'
;

DefineSystemAction(DumpRouteTable)
    execAction(cmd) {
        mapModeDatabase.getMapLocation().dumpRouteTable();
    }
;
#endif

class CarryMap: Decoration {
    vocab = 'mental map'
    bulk = 0
    dobjFor(Search) asDobjFor(Examine)
    dobjFor(Examine) {
        verify() { }
        check() { }
        action() {
            doInstead(ToggleMapMode);
        }
        report() { }
    }
}

class CarryCompass: Decoration {
    vocab = 'mental compass'
    bulk = 0
    dobjFor(Search) asDobjFor(Examine)
    dobjFor(Examine) {
        verify() { }
        check() { }
        action() {
            doInstead(MapModeCompass);
        }
        report() { }
    }
}

modify Room {
    mapModeVersion = nil
    actualRoom = nil
    isMapModeRoom = nil
    mapModeDirections = nil
    mapModeLockedDoors = nil

    elligibleForMapMode() {
        return ((valToList(mapModeDirections)).length
            + (valToList(mapModeLockedDoors)).length) > 0;
    }

    initMapModeVersion() {
        mapModeVersion = MapModeRoom.createInstance(self);
        mapModeVersion.preinitThing();
        mapModeDatabase.allRooms.append(mapModeVersion);
    }
}

mapModeDatabase: object {
    inMapMode = nil
    firstTimeMapMode = nil
    actualPlayerChar = nil
    mapModeStart = nil
    compassTarget = nil

    allRooms = static new Vector()

    notOnMapMsg = 'You cannot see that on your map.
        It might exist, omitted from the map, or it might
        not be in the facility at all. '
    noRouteOnMapMsg = 'You cannot see a way there on your map.
        A hidden route might be omitted from the map, or it might
        not exist in the facility at all. '

    cancelNonMapAction() {
        "You cannot do that in map mode.\n
        The available actions in map mode are:\n";
        if (gFormatForScreenReader) {
            "<b>GO</b> <i>(direction)</i>, <b>GO TO</b> <i>(location)</i>,
            <b>EXAMINE COMPASS</b>, and <b>LOOK AROUND</b>. ";
        }
        else {
            """
            \t<tt>[&gt;&gt;]</tt> <b>GO</b> <i>(direction)</i>\n
            \t<tt>[&gt;&gt;]</tt> <b>GO TO</b> <i>(location)</i>\n
            \t<tt>[&gt;&gt;]</tt> <b>COMPASS</b>\n
            \t<tt>[&gt;&gt;]</tt> <b>LOOK AROUND</b>
            """;
        }
        //exit;
    }

    setGoto(target) {
        local room = target;
        if (!target.ofKind(Room)) {
            room = target.getOutermostRoom();
        }
        if (room.isMapModeRoom) {
            room = room.actualRoom;
        }
        
        if (room.mapModeVersion == nil) {
            say(notOnMapMsg);
            exit;
        }

        if (getMapLocation().playerRouteTable.hasDirectionTo(room.mapModeVersion) == nil) {
            say(noRouteOnMapMsg);
        }

        compassTarget = room;

        "Compass set to: <<compassTarget.roomTitle>> ";
    }

    checkCompass() {
        if (compassTarget == nil) {
            "You have not set your compass yet.\n
            Use the <b>GO TO</b> command.\n
            \tExample: <b>GO TO HANGAR</b>";
            exit;
        }

        local mapLocation = getMapLocation();
        local goalRoom = compassTarget.mapModeVersion;
        local nextDir = mapLocation.playerRouteTable.findBestDirectionTo(goalRoom);
        reportBestDirectionTo(nextDir);
    }

    getMapLocation() {
        checkMapEntry();
        local currentMapModeRoom = gPlayerChar.getOutermostRoom();
        if (!inMapMode) {
            currentMapModeRoom = currentMapModeRoom.mapModeVersion;
        }
        return currentMapModeRoom;
    }

    checkMapEntry() {
        if (inMapMode) return;
        if (gPlayerChar.getOutermostRoom().mapModeVersion == nil) {
            "Your current location is not visible on the map. ";
            exit;
        }
    }

    mapModeOn() {
        checkMapEntry();
        inMapMode = true;
        "<.p><tt>MAP MODE IS NOW ON.</tt><.p>";
        if (!firstTimeMapMode) {
            firstTimeMapMode = true;
            "In map mode, you explore a simplified version of the world.
            Your available actions will be limited, but you will also not
            spend turns.<.p>";
        }
        actualPlayerChar = gPlayerChar;
        mapModeStart = actualPlayerChar.getOutermostRoom().mapModeVersion;
        mapModePlayer.moveInto(mapModeStart);
        setPlayer(mapModePlayer);
        mapModeStart.lookAroundWithin();
    }

    mapModeOff() {
        inMapMode = nil;
        "<.p><tt>MAP MODE IS NOW OFF.</tt><.p>";
        setPlayer(actualPlayerChar);
        actualPlayerChar.getOutermostRoom().lookAroundWithin();
    }

    resetPathCalculation() {
        for (local i = 1; i <= allRooms.length; i++) {
            allRooms[i].pathCalculationScore = allRooms.length + 2;
        }
    }

    calculatePathBetween(startMapRoom, endMapRoom) {
        startMapRoom.calculatePathBetweenMeAnd(endMapRoom);
    }

    reportBestDirectionTo(direction) {
        if (direction == compassAlreadyHereSignal) {
            "You have arrived at your destination. ";
            exit;
        }
        if (direction == nil) {
            say(mapModeDatabase.noRouteOnMapMsg);
            exit;
        }
        direction.sayDir(
            'NEXT STEP: ',
            'To reach <<mapModeDatabase.compassTarget.roomTitle>>,
            you must '
        );
    }
}

mapModePlayer: Actor { 'avatar;;me self myself'
    "You are as you appear in your own imagination. "
}

+CarryMap;
+CarryCompass;

class MapModeDirection: object {
    construct(_dirProp, _dest, _conn, _isLockedDoor?) {
        dirProp = _dirProp;
        destination = _dest;
        connector = _conn;
        isLockedDoor = _isLockedDoor;
    }
    dirProp = nil
    destination = nil
    connector = nil
    isLockedDoor = nil

    getDirOrder() {
        if (isLockedDoor) return 13;

        if (dirProp == &north) return 1;
        if (dirProp == &northeast) return 2;
        if (dirProp == &east) return 3;
        if (dirProp == &southeast) return 4;
        if (dirProp == &south) return 5;
        if (dirProp == &southwest) return 6;
        if (dirProp == &west) return 7;
        if (dirProp == &northwest) return 8;
        if (dirProp == &up) return 9;
        if (dirProp == &down) return 10;
        if (dirProp == &in) return 11;
        return 12;
    }

    getDirNameFromProp() {
        if (isLockedDoor) return 'through a door';
        
        if (dirProp == &north) return 'north';
        if (dirProp == &northeast) return 'northeast';
        if (dirProp == &east) return 'east';
        if (dirProp == &southeast) return 'southeast';
        if (dirProp == &south) return 'south';
        if (dirProp == &southwest) return 'southwest';
        if (dirProp == &west) return 'west';
        if (dirProp == &northwest) return 'northwest';
        if (dirProp == &up) return 'up';
        if (dirProp == &down) return 'down';
        if (dirProp == &in) return 'in';
        return 'out';
    }

    isDirHorizontal() {
        if (dirProp == &up) return nil;
        if (dirProp == &down) return nil;
        if (dirProp == &in) return nil;
        if (dirProp == &out) return nil;
        return true;
    }

    getHyperDir() {
        return (isDirHorizontal() ? 'to the ' : 'by going ')
            + hyperDir(getDirNameFromProp());
    }

    sayDir(prefix, screenReaderPrefix) {
        if (gFormatForScreenReader) {
            "<<screenReaderPrefix>>go to <<destination.actualRoom.roomTitle>>
            <<getHyperDir()>>.";
        }
        else {
            "<<prefix>><<destination.actualRoom.roomTitle
            >>\n\t(<<getHyperDir()>>)";
        }
    }

    getSkashekDir() {
        local roomName = ' to ' + destination.actualRoom.roomTitle;
        if (isLockedDoor) {
            return 'through '
                + connector.soundSourceRepresentative.theName + roomName;
        }
        return getDirNameFromProp() + roomName;
    }
}

class RouteTable: object {
    construct(_parentRoom, _isForSkashek) {
        parentRoom = _parentRoom;
        knownDirections = new Vector();
        isForSkashek = _isForSkashek;
        fellowProp = isForSkashek ? &skashekRouteTable : &playerRouteTable;
    }

    isForSkashek = nil
    parentRoom = nil
    table = nil
    knownDirections = nil
    fellowProp = nil

    showAvailableDirections() {
        if (knownDirections == nil || knownDirections.length == 0) {
            "The map does not show any way out of here. ";
            return;
        }
        "The map shows the following exits:";
        for (local i = 1; i <= knownDirections.length; i++) {
            knownDirections[i].sayDir('\n', '\nYou can ');
        }
    }

    createLinks() {
        local directionList = valToList(parentRoom.actualRoom.mapModeDirections);

        // Basic directions
        for (local i = 1; i <= directionList.length; i++) {
            local dirProp = directionList[i];
            local actualDestination = parentRoom.actualRoom.(dirProp);
            if (!actualDestination.ofKind(Room)) {
                actualDestination = actualDestination.destination.getOutermostRoom();
            }
            if (actualDestination.mapModeVersion == nil) continue;
            knownDirections.append(new MapModeDirection(
                dirProp,
                actualDestination.mapModeVersion,
                actualDestination.mapModeVersion
            ));

            // Only build the connectors once.
            // Arbitrarily do this for player's table only.
            if (!isForSkashek) {
                parentRoom.(dirProp) = actualDestination.mapModeVersion;
            }
        }

        // Locked doors (Skashek's route table only)
        if (isForSkashek) {
            local doorList = valToList(parentRoom.actualRoom.mapModeLockedDoors);
            for (local i = 1; i <= doorList.length; i++) {
                local door = doorList[i];
                local actualDestination = door.otherSide.getOutermostRoom();
                if (actualDestination.mapModeVersion == nil) continue;
                knownDirections.append(new MapModeDirection(
                    nil,
                    actualDestination.mapModeVersion,
                    door,
                    true
                ));
            }
        }

        knownDirections.sort(nil, { a, b: a.getDirOrder() - b.getDirOrder() });
    }

    calculatePathBetweenMeAnd(endMapRoom) {
        populate();
        mapModeDatabase.resetPathCalculation();
        calculateRouteTo(endMapRoom, 0);
    }

    populate() {
        if (table == nil) {
            table = new Vector(mapModeDatabase.allRooms.length);
            for (local i = 1; i <= mapModeDatabase.allRooms.length; i++) {
                table.append(nil);
            }
        }
    }

    calculateRouteTo(mapModeRoom, currentSteps) {
        if (mapModeRoom == parentRoom) return currentSteps;
        if (currentSteps >= parentRoom.pathCalculationScore) return -1;
        parentRoom.pathCalculationScore = currentSteps;

        local startLowest = 10000;
        local lowest = startLowest;
        local lowestDirection = nil;

        for (local i = 1; i <= knownDirections.length; i++) {
            local attemptDir = knownDirections[i];
            local attempt = attemptDir.destination.(fellowProp);
            local stepCount = attempt.calculateRouteTo(mapModeRoom, currentSteps + 1);
            if (stepCount < 0) continue;
            if (stepCount < lowest) {
                lowest = stepCount;
                lowestDirection = attemptDir;
            }
        }

        local res = (lowest == startLowest) ? -1 : lowest;

        if (currentSteps == 0) {
            table[mapModeRoom.mapRoomIndex] = lowestDirection;
        }

        return res;
    }

    hasDirectionTo(mapModeRoom) {
        return findBestDirectionTo(mapModeRoom) != nil;
    }

    findBestDirectionTo(mapModeRoom) {
        if (mapModeRoom == parentRoom) {
            return compassAlreadyHereSignal;
        }

        return table[mapModeRoom.mapRoomIndex];
    }

    dump() {
        "\bRoute table length: <<table.length>>";
        for (local i = 1; i <= table.length; i++) {
            "\n<<mapModeDatabase.allRooms[i].actualRoom.roomTitle>>:
            <<(table[i] == nil) ? 'no route' : 'has route'>>";
        }
    }
}

class MapModeRoom: Room {
    construct(_actual) {
        actualRoom = _actual;
        vocab = _actual.vocab;
        roomTitle = _actual.roomTitle + ' (IN MAP MODE)';
        inherited Room.construct();
        mapRoomIndex = mapModeDatabase.allRooms.length + 1;
        playerRouteTable = new RouteTable(self, nil);
        skashekRouteTable = new RouteTable(self, true);
    }

    isMapModeRoom = true
    familiar = true
    mapRoomIndex = -1

    pathCalculationScore = 10000
    playerRouteTable = nil
    skashekRouteTable = nil

    ceilingObj = mapModeCeiling
    wallsObj = mapModeWalls
    floorObj = mapModeFloor

    calculatePathBetweenMeAnd(endMapRoom) {
        playerRouteTable.calculatePathBetweenMeAnd(endMapRoom);
        skashekRouteTable.calculatePathBetweenMeAnd(endMapRoom);
    }

    desc() {
        playerRouteTable.showAvailableDirections();
    }

    createLinks() {
        playerRouteTable.createLinks();
        skashekRouteTable.createLinks();
    }

    dumpRouteTable() {
        playerRouteTable.dump();
    }
}

compassAlreadyHereSignal: object;

#define standardMapModeSurfaceDesc \
    "A black surface, outlined in white marker, but only \
    a metaphor for your sense of direction. "

mapModeCeiling: Ceiling { 'ceiling'
    standardMapModeSurfaceDesc
}

mapModeWalls: Walls { 'walls;north n south s east e west w'
    standardMapModeSurfaceDesc
}

mapModeFloor: Floor { 'floor;;ground'
    standardMapModeSurfaceDesc
}

mapModePreinit: PreinitObject {
    executeBeforeMe = [thingPreinit]

    execute() {
        local startingRooms = new Vector(64);
        for (local cur = firstObj(Room);
            cur != nil ; cur = nextObj(cur, Room)) {
            startingRooms.append(cur);
        }

        for (local i = 1; i <= startingRooms.length; i++) {
            local startingRoom = startingRooms[i];
            if (!startingRoom.elligibleForMapMode()) continue;
            startingRoom.initMapModeVersion();
        }

        for (local i = 1; i <= mapModeDatabase.allRooms.length; i++) {
            local mapModeRoom = mapModeDatabase.allRooms[i];
            mapModeRoom.createLinks();
        }

        // Cache paths
        for (local i = 1; i <= mapModeDatabase.allRooms.length; i++) {
            for (local j = 1; j <= mapModeDatabase.allRooms.length; j++) {
                if (i == j) continue;
                mapModeDatabase.calculatePathBetween(
                    mapModeDatabase.allRooms[i],
                    mapModeDatabase.allRooms[j]
                );
            }
        }

        // Set up misc map anatomy
        mapModeCeiling.addToLocations();
        mapModeWalls.addToLocations();
        mapModeFloor.addToLocations();
    }
}
