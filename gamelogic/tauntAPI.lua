-- ============================================
-- TAUNT API SYSTEM
-- Datei: gamelogic/tauntAPI.lua
-- ============================================

TauntAPI = {
    taunts = {},
    useOriginalTaunts = true,
    currentIndex = 1,
    playbackMode = "random" -- "random", "sequential", "single"
}

--- Registriert einen neuen Taunt
--- @param id string Eindeutige ID für den Taunt
--- @param soundPath string Pfad zur Sound-Datei
--- @param weight number Optional: Gewichtung für Random-Auswahl (default: 1)
--- @return boolean success Ob die Registrierung erfolgreich war
function TauntAPI.registerTaunt(id, soundPath, weight)
    if not id or not soundPath then
        DebugPrint("[TauntAPI] Error: ID und soundPath sind erforderlich!")
        return false
    end
    
    weight = weight or 1
    
    -- Prüfen ob Sound existiert
    local sound = LoadSound(soundPath)
    if not sound then
        DebugPrint("[TauntAPI] Warning: Sound konnte nicht geladen werden: " .. soundPath)
        return false
    end
    
    TauntAPI.taunts[id] = {
        id = id,
        soundPath = soundPath,
        sound = sound,
        weight = weight,
        enabled = true
    }
    
    DebugPrint("[TauntAPI] Taunt registriert: " .. id)
    return true
end

--- Deaktiviert die Original-Taunts
function TauntAPI.disableOriginalTaunts()
    TauntAPI.useOriginalTaunts = false
    DebugPrint("[TauntAPI] Original Taunts deaktiviert")
end

--- Aktiviert die Original-Taunts wieder
function TauntAPI.enableOriginalTaunts()
    TauntAPI.useOriginalTaunts = true
    DebugPrint("[TauntAPI] Original Taunts aktiviert")
end

--- Setzt den Playback-Modus
--- @param mode string "random", "sequential", oder "single"
function TauntAPI.setPlaybackMode(mode)
    if mode == "random" or mode == "sequential" or mode == "single" then
        TauntAPI.playbackMode = mode
        DebugPrint("[TauntAPI] Playback-Modus gesetzt auf: " .. mode)
    else
        DebugPrint("[TauntAPI] Error: Ungültiger Playback-Modus: " .. mode)
    end
end

--- Gibt die Anzahl der registrierten Taunts zurück
--- @return number count Anzahl der Taunts
function TauntAPI.getCount()
    local count = 0
    for id, taunt in pairs(TauntAPI.taunts) do
        if taunt.enabled then
            count = count + 1
        end
    end
    return count
end

--- Aktiviert/Deaktiviert einen spezifischen Taunt
--- @param id string Taunt ID
--- @param enabled boolean Aktiviert oder deaktiviert
function TauntAPI.setTauntEnabled(id, enabled)
    if TauntAPI.taunts[id] then
        TauntAPI.taunts[id].enabled = enabled
        DebugPrint("[TauntAPI] Taunt " .. id .. " " .. (enabled and "aktiviert" or "deaktiviert"))
    end
end

--- Wählt einen Taunt basierend auf dem aktuellen Playback-Modus
--- @return table|nil taunt Der ausgewählte Taunt oder nil
function TauntAPI.selectTaunt()
    -- Erstelle Liste der aktivierten Taunts
    local enabledTaunts = {}
    for id, taunt in pairs(TauntAPI.taunts) do
        if taunt.enabled then
            table.insert(enabledTaunts, taunt)
        end
    end
    
    if #enabledTaunts == 0 then
        return nil
    end
    
    if TauntAPI.playbackMode == "random" then
        -- Gewichtete Zufallsauswahl
        local totalWeight = 0
        for _, taunt in ipairs(enabledTaunts) do
            totalWeight = totalWeight + taunt.weight
        end
        
        local random = math.random() * totalWeight
        local currentWeight = 0
        
        for _, taunt in ipairs(enabledTaunts) do
            currentWeight = currentWeight + taunt.weight
            if random <= currentWeight then
                return taunt
            end
        end
        
        return enabledTaunts[1]
        
    elseif TauntAPI.playbackMode == "sequential" then
        -- Sequenzielle Auswahl
        TauntAPI.currentIndex = TauntAPI.currentIndex % #enabledTaunts + 1
        return enabledTaunts[TauntAPI.currentIndex]
        
    elseif TauntAPI.playbackMode == "single" then
        -- Immer den ersten
        return enabledTaunts[1]
    end
    
    return nil
end

--- Spielt einen Taunt ab
--- @param pos vector Position wo der Sound abgespielt werden soll
--- @param volume number Optional: Lautstärke (default: 2)
--- @return boolean success Ob der Taunt erfolgreich abgespielt wurde
function TauntAPI.playTaunt(pos, volume)
    volume = volume or 2
    
    if TauntAPI.useOriginalTaunts then
        -- Original Taunt abspielen
        if server and server.assets and server.assets.taunt then
            PlaySound(server.assets.taunt, pos, volume, true, 1)
            return true
        end
        return false
    end
    
    -- Custom Taunt abspielen
    local taunt = TauntAPI.selectTaunt()
    if taunt and taunt.sound then
        PlaySound(taunt.sound, pos, volume, true, 1)
        DebugPrint("[TauntAPI] Taunt abgespielt: " .. taunt.id)
        return true
    end
    
    DebugPrint("[TauntAPI] Warning: Kein Taunt zum Abspielen gefunden!")
    return false
end

--- Entfernt einen Taunt
--- @param id string Taunt ID
function TauntAPI.unregisterTaunt(id)
    if TauntAPI.taunts[id] then
        TauntAPI.taunts[id] = nil
        DebugPrint("[TauntAPI] Taunt entfernt: " .. id)
    end
end

--- Gibt alle registrierten Taunts zurück
--- @return table taunts Liste aller Taunts
function TauntAPI.getAllTaunts()
    local result = {}
    for id, taunt in pairs(TauntAPI.taunts) do
        table.insert(result, {
            id = taunt.id,
            enabled = taunt.enabled,
            weight = taunt.weight
        })
    end
    return result
end

--- Setzt alle Einstellungen zurück
function TauntAPI.reset()
    TauntAPI.taunts = {}
    TauntAPI.useOriginalTaunts = true
    TauntAPI.currentIndex = 1
    TauntAPI.playbackMode = "random"
    DebugPrint("[TauntAPI] Reset durchgeführt")
end