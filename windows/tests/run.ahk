#Requires AutoHotkey v2.0
#NoTrayIcon
#Warn VarUnset, Off

#Include TestKit.ahk
#Include FakePort.ahk
#Include ..\lib\Core.ahk

REPO_ROOT := RegExReplace(A_LineFile, "\\windows\\tests\\run\.ahk$")

; Config as shipped in the repo (no local overrides).
TestConfig() {
    return LoadConfig(REPO_ROOT "\config.ini", "")
}

#Include TestConfig.ahk
#Include TestFormat.ahk
#Include TestFocusClaude.ahk
#Include TestSendToClaude.ahk
#Include TestPalette.ahk
#Include TestBindings.ahk

T_Finish()
