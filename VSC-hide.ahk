#Requires AutoHotkey v2.0

LastActive := 0

~LAlt Up::
{
    Global LastActive
    Sleep(100)

    CurrentWin := WinExist("A")

    if WinActive("ahk_exe Code.exe") && CurrentWin != LastActive {
        for id in WinGetList() {
            try {
                if (WinGetExStyle(id) & 0x80)         ; WS_EX_TOOLWINDOW
                    continue
                if !(WinGetStyle(id) & 0x20000)       ; WS_MINIMIZEBOX
                    continue

                if (WinGetProcessName(id) = "Code.exe")
                    continue

                PostMessage(0x0112, 0xF020, , , id)   ; WM_SYSCOMMAND, SC_MINIMIZE
            }
        }
    }
    LastActive := CurrentWin
}
