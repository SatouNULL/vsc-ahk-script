#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; ---------------- config ----------------
JsonPath  := A_AppData "\Code\User\settings.json"
JsonKey   := "glassit.alpha"
CallValue := "255"       ; opaque VS Code while in a call; previous value is restored afterwards
PollMs := 3000
ChromiumBrowsers := ["chrome.exe", "msedge.exe", "brave.exe", "opera.exe", "vivaldi.exe", "chromium.exe", "Arc.exe"]
FirefoxBrowsers  := ["firefox.exe", "librewolf.exe", "waterfox.exe", "floorp.exe", "zen.exe"]
CallApps         := ["Teams.exe", "MSTeams", "Zoom.exe", "Loom.exe"]   ; non-browser apps whose mic use counts as a call
; ----------------------------------------

InCall := false
WEStopped := false
SavedValue := ""

SetTimer(Check, PollMs)
Check()

Check() {
    Global InCall, WEStopped, SavedValue
    active := IsInCall()
    if (active = InCall)
        return
    InCall := active

    if active {
        SavedValue := SetJson(CallValue)
        SetVSCodeAlpha(CallValue)
        WEStopped := WallpaperControl("stop")
    } else {
        if (SavedValue != "") {
            SetJson(SavedValue)
            SetVSCodeAlpha(SavedValue)
        }
        if WEStopped
            WallpaperControl("play")
        WEStopped := false
    }
}

; GlassIt doesn't pick up external edits to settings.json, so apply the alpha to the windows directly
SetVSCodeAlpha(alpha) {
    if !IsInteger(alpha)
        return
    for id in WinGetList("ahk_exe Code.exe")
        try WinSetTransparent(Integer(alpha), id)
}

; Wallpaper Engine's own CLI; "stop" unloads wallpapers and frees resources without the
; crash/Safe Start prompt that killing the process causes. Returns false if WE isn't running.
WallpaperControl(cmd) {
    for exe in ["wallpaper64.exe", "wallpaper32.exe"] {
        if (pid := ProcessExist(exe)) {
            try {
                Run('"' ProcessGetPath(pid) '" -control ' cmd)
                return true
            }
        }
    }
    return false
}

IsInCall() {
    if DeviceInUse("webcam")                                                    ; any app using the camera
        return true
    micApps := []
    micApps.Push(ChromiumBrowsers*), micApps.Push(FirefoxBrowsers*), micApps.Push(CallApps*)
    if DeviceInUse("microphone", micApps)                                       ; browser / Teams call (camera off)
        return true
    for exe in ChromiumBrowsers
        if WinExist("is sharing ahk_exe " exe)                                  ; "x is sharing your screen" bar
            return true
    for exe in FirefoxBrowsers
        if WinExist("Sharing Indicator ahk_exe " exe)                           ; camera/mic/screen sharing indicator
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
        if (RegReadQword(A_LoopRegKey, "LastUsedTimeStop") !== 0)
            continue
        if !RegReadQword(A_LoopRegKey, "LastUsedTimeStart")
            continue
        if !IsObject(apps)
            return true
        for app in apps
            if InStr(A_LoopRegKey, app)
                return true
    }
    return false
}

; RegRead() can't read REG_QWORD, so query HKCU directly; returns "" if missing
RegReadQword(key, name) {
    subKey := SubStr(key, InStr(key, "\") + 1)
    buf := Buffer(8, 0), size := 8
    if DllCall("advapi32\RegGetValueW", "Ptr", 0x80000001, "Str", subKey, "Str", name
        , "UInt", 0x48, "Ptr", 0, "Ptr", buf, "UInt*", &size) != 0    ; HKEY_CURRENT_USER, RRF_RT_QWORD
        return ""
    return NumGet(buf, "Int64")
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
