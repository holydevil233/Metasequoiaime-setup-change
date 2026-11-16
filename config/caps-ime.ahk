#Requires AutoHotkey v2.0
#SingleInstance Force

SetCapsLockState "AlwaysOff"

CapsLock:: {
    SendEvent "{LShift down}{LShift up}"
}

*LShift:: {
    Send "{Blind}{LShift down}"
}
*LShift up:: {
    if (A_PriorKey = "LShift")
        Send "{Blind}{vkE8}"
    Send "{Blind}{LShift up}"
}

*RShift:: {
    Send "{Blind}{RShift down}"
}
*RShift up:: {
    if (A_PriorKey = "RShift")
        Send "{Blind}{vkE8}"
    Send "{Blind}{RShift up}"
}
