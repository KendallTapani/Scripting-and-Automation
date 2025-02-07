#Requires AutoHotkey v2.0
#SingleInstance Force

; PowerShell commands
^,:: {  ; Ctrl + ,
    Run "powershell.exe -NoProfile -Command Import-Module 'C:\Scripts\Job\JobSearch.psm1'; Open-JobPortals"
}

^.:: {  ; Ctrl + .
    Run "powershell.exe -NoProfile -Command Import-Module 'C:\Scripts\Job\JobSearch.psm1'; Get-ApplicationInfo"
}

^/:: {  ; Ctrl + /
    subject := FileRead("C:\Scripts\Job\Config\subject_template.txt")
    body := FileRead("C:\Scripts\Job\Config\email_template.txt")
    
    Send "n"
    Sleep 200
    Send "{Tab}"
    Sleep 100
    A_Clipboard := subject
    Send "^v"
    Sleep 100
    Send "{Tab}"
    Sleep 100
    A_Clipboard := body
    Send "^v"
}

; Read personal info file
personalInfo := FileRead("C:\Scripts\Job\Config\personal_info.txt")
Lines := StrSplit(personalInfo, "`n", "`r")

; Hotkeys for personal info
^0:: {  ; Full Name
    A_Clipboard := Lines[1]
    Sleep 25
    Send "^v"
    Sleep 25
    Send "{Tab}"
}

^9:: {  ; Phone
    A_Clipboard := Lines[2]
    Sleep 25
    Send "^v"
    Sleep 25
    Send "{Tab}"
}

^8:: {  ; Email
    A_Clipboard := Lines[3]
    Sleep 25
    Send "^v"
    Sleep 25
    Send "{Tab}"
}

^7:: {  ; Address
    A_Clipboard := Lines[4]
    Sleep 25
    Send "^v"
    Sleep 25
    Send "{Tab}"
}

^6:: {  ; Zipcode
    A_Clipboard := Lines[5]
    Sleep 25
    Send "^v"
    Sleep 25
    Send "{Tab}"
}

^5:: {  ; LinkedIn
    A_Clipboard := Lines[6]
    Sleep 25
    Send "^v"
    Sleep 25
    Send "{Tab}"
}

^4:: {  ; Github
    A_Clipboard := Lines[7]
    Sleep 25
    Send "^v"
    Sleep 25
    Send "{Tab}"
}

^3:: {  ; Job Title
    A_Clipboard := Lines[8]
    Sleep 25
    Send "^v"
    Sleep 25
    Send "{Tab}"
}