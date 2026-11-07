#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; ---------------- config ----------------
JsonPath  := A_AppData "\Code\User\settings.json"
JsonKey   := "glassit.alpha"
CallValue := "255"       ; opaque VS Code while in a call; previous value is restored afterwards
PollMs := 1000
EndDelayMs := 5000       ; time without sharing before restoring (avoids flicker when a share toolbar briefly hides)
ChromiumBrowsers := ["chrome.exe", "msedge.exe", "brave.exe", "opera.exe", "vivaldi.exe", "chromium.exe", "Arc.exe"]
FirefoxBrowsers  := ["firefox.exe", "librewolf.exe", "waterfox.exe", "floorp.exe", "zen.exe"]
ShareWindows     := [                          ; windows that only exist while an app is screen sharing (find with Window Spy)
    "Meeting compact view ahk_exe ms-teams.exe",
    "ahk_class ZPFloatToolbarClass ahk_exe Zoom.exe"
]
; ----------------------------------------

InCall := false
WEStopped := false
SavedValue := ""
LastSeen := 0

SetTimer(Check, PollMs)
Check()

; React as soon as any window is shown instead of waiting for the next poll
DllCall("SetWinEventHook", "UInt", 0x8002, "UInt", 0x8002, "Ptr", 0         ; EVENT_OBJECT_SHOW
    , "Ptr", CallbackCreate(OnWindowShown), "UInt", 0, "UInt", 0, "UInt", 0)  ; WINEVENT_OUTOFCONTEXT

OnWindowShown(hook, event, hwnd, idObject, idChild, thread, time) {
    if (idObject = 0 && idChild = 0)    ; OBJID_WINDOW, not carets/menus/etc.
        SetTimer(CheckNow, -1)
}

CheckNow() => Check()                   ; separate function so it doesn't replace the Check poll timer

Check() {
    Global InCall, WEStopped, SavedValue, LastSeen
    active := IsInCall()
    if active
        LastSeen := A_TickCount
    if (active = InCall)
        return
    if (!active && A_TickCount - LastSeen < EndDelayMs)
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
    for exe in ChromiumBrowsers
        if WinExist("is sharing ahk_exe " exe)                                  ; "x is sharing your screen" bar
            return true
    for exe in FirefoxBrowsers
        if WinExist("Sharing Indicator ahk_exe " exe)                           ; Firefox sharing indicator
            return true
    for title in ShareWindows
        if WinExist(title)
            return true
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
