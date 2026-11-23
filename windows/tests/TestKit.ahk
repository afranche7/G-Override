; Minimal assertion runner for the Windows Helper tests.
; Run all tests: AutoHotkey64.exe /ErrorStdOut windows\tests\run.ahk  (exit code = number of failures)

global T_pass := 0
global T_fail := 0

T_Out(s) {
    try FileAppend(s "`n", "*", "UTF-8")
}

Test(name, fn) {
    global T_pass, T_fail
    try {
        fn()
        T_pass += 1
        T_Out("ok   " name)
    } catch as e {
        T_fail += 1
        T_Out("FAIL " name "`n     " e.Message (e.Extra != "" ? " (" e.Extra ")" : ""))
    }
}

AssertEq(actual, expected, msg := "") {
    if !(T_Str(actual) == T_Str(expected))
        throw Error((msg != "" ? msg ": " : "") "expected <" T_Str(expected) "> but got <" T_Str(actual) ">")
}

AssertTrue(cond, msg := "expected true") {
    if !cond
        throw Error(msg)
}

AssertFalse(cond, msg := "expected false") {
    if cond
        throw Error(msg)
}

AssertContains(haystack, needle, msg := "") {
    if !InStr(T_Str(haystack), needle, true)
        throw Error((msg != "" ? msg ": " : "") "expected <" T_Str(haystack) "> to contain <" needle ">")
}

AssertNotContains(haystack, needle, msg := "") {
    if InStr(T_Str(haystack), needle, true)
        throw Error((msg != "" ? msg ": " : "") "expected <" T_Str(haystack) "> not to contain <" needle ">")
}

T_Str(v) {
    if IsObject(v) {
        if v is Array {
            s := "["
            for i, x in v
                s .= (i > 1 ? ", " : "") T_Str(x)
            return s "]"
        }
        return "{object}"
    }
    return String(v)
}

T_Finish() {
    global T_pass, T_fail
    T_Out("`n" T_pass " passed, " T_fail " failed")
    ExitApp(T_fail)
}

; True if fn() throws.
Throws(fn) {
    try fn()
    catch
        return true
    return false
}
