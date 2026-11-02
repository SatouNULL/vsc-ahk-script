#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; ---------------- config ----------------
JsonPath  := "C:\path\to\your\file.json"
JsonKey   := "someKey"
CallValue := "true"      ; raw JSON written while in a call (use '"text"' for a string)
IdleValue := "false"     ; raw JSON written when the call ends
RestartWallpaper := true ; relaunch Wallpaper Engine after the call
WEPath := "C:\Program Files (x86)\Steam\steamapps\common\wallpaper_engine\wallpaper64.exe"
PollMs := 3000
; ----------------------------------------

InCall := false
WEWasRunning := false
SavedValue := ""

SetTimer(Check, PollMs)
Check()

Check() {
    Global InCall, WEWasRunning, SavedValue
    active := IsInCall()
    if (active = InCall)
        return
    InCall := active

    if active {
        SavedValue := SetJson(CallValue)
        WEWasRunning := KillWallpaper()
    } else {
        if (SavedValue != "")
            SetJson(SavedValue)
        if RestartWallpaper && WEWasRunning && FileExist(WEPath)
            Run(WEPath)
    }
}

IsInCall() {
    if DeviceInUse("webcam")                                                    ; any app using the camera
        return true
    if DeviceInUse("microphone", ["chrome.exe", "Teams.exe", "MSTeams"])        ; Meet / Teams call (camera off)
        return true
    if WinExist("is sharing ahk_exe chrome.exe")                                ; Chrome "x is sharing your screen" bar
        return true
    if WinExist("Sharing control bar ahk_exe ms-teams.exe")                     ; Teams screen share toolbar
        return true
    return false
}

; Windows records camera/mic use per app; LastUsedTimeStop = 0 means "still in use"
DeviceInUse(device, apps := "") {
    root := "HKCU\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\" device
    Loop Reg, root, "R" {
        if (A_LoopRegName != "LastUsedTimeStop")
            continue
        if (RegRead() != 0)
            continue
        if (RegRead(A_LoopRegKey, "LastUsedTimeStart", 0) = 0)
            continue
        if !IsObject(apps)
            return true
        for app in apps
            if InStr(A_LoopRegKey, app)
                return true
    }
    return false
}

; Replaces the key's value in place (comments/formatting kept) and returns the old value
SetJson(value) {
    if !FileExist(JsonPath)
        return ""
    text := FileRead(JsonPath, "UTF-8")
    pattern := '("\Q' JsonKey '\E"\s*:\s*)("(?:[^"\\]|\\.)*"|[^,}\]\s/]+)'
    if !RegExMatch(text, pattern, &m)
        return ""
    if (m[2] != value) {
        newText := SubStr(text, 1, m.Pos[2] - 1) value SubStr(text, m.Pos[2] + m.Len[2])
        f := FileOpen(JsonPath, "w", "UTF-8-RAW")
        f.Write(newText)
        f.Close()
    }
    return m[2]
}

KillWallpaper() {
    Global WEPath
    killed := false
    for exe in ["wallpaper64.exe", "wallpaper32.exe", "webwallpaper32.exe", "ui32.exe"] {
        Loop 5 {
            if !(pid := ProcessExist(exe))
                break
            if InStr(exe, "wallpaper") = 1
                try WEPath := ProcessGetPath(pid)
            ProcessClose(pid)
            ProcessWaitClose(pid, 2)
            killed := true
        }
    }
    return killed
}
