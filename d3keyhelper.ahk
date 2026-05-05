#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn

InstallKeybdHook()
InstallMouseHook()
SetWorkingDir(A_ScriptDir)
SetKeyDelay(-1, -1)
CoordMode("Pixel", "Client")
CoordMode("Mouse", "Client")
ProcessSetPriority("High")

VERSION := 260403
CONFIG_FILE := "d4keyhelper.ini"
GAME_PROCESS := "Diablo IV.exe"
GAME_WINDOW := "ahk_exe " GAME_PROCESS
TITLE := Format("暗黑4技能连点器 v2.0.{:d}", VERSION)

actionItems := ["禁用", "按住不放", "连点", "保持Buff", "按键触发"]
methodItems := ["无", "鼠标中键", "滚轮向上", "滚轮向下", "侧键1", "侧键2", "键盘按键"]
startItems := ["鼠标右键", "鼠标中键", "滚轮向上", "滚轮向下", "侧键1", "侧键2", "键盘按键"]
startModeItems := ["懒人模式", "仅按下时", "仅按一次"]
quickPauseClickItems := ["双击", "单击", "压住"]
quickPauseButtonItems := ["鼠标左键", "鼠标右键", "鼠标中键", "侧键1", "侧键2"]
quickPauseActionItems := ["暂停按键宏", "暂停宏且连点左键"]
movingItems := ["无", "强制站立", "强制走位（按住不放）", "强制走位（连点）"]
potionItems := ["无", "定时连点", "保持药水CD"]
mouseMethodKeys := ["", "MButton", "WheelUp", "WheelDown", "XButton1", "XButton2", ""]
startMethodKeys := ["RButton", "MButton", "WheelUp", "WheelDown", "XButton1", "XButton2", ""]
quickPauseKeys := ["LButton", "RButton", "MButton", "XButton1", "XButton2"]
skillLabels := ["技能一：", "技能二：", "技能三：", "技能四：", "左键技能：", "右键技能："]

profiles := []
profileNames := []
general := Map()
controls := Map()
skillControls := []
profileKeybinding := Map()
keysOnHold := Map()
skillQueue := []
skillTimers := Map()
triggerHotkeys := Map()
syncTimer := Map()
syncDelay := Map()
lastPotion := []
mainGui := ""
currentProfile := 1
vRunning := false
vPausing := false
startRunHK := ""
quickPauseHK := ""
gameW := 0
gameH := 0
gameX := 0
gameY := 0
forceStandingKey := "LShift"
forceMovingKey := "e"
potionKey := "q"
queueTimerFn := ""
potionTimerFn := ""
movingTimerFn := ""

ReadCfgFile()
SendMode(general["sendmode"])
CreateGui()
LoadProfileToControls(currentProfile)
SetTrayMenu()
RegisterAllHotkeys()
SetTimer((*) => WatchActiveWindow(), 500)
mainGui.Show("w980 h570")
OnExit((*) => OnUnload())

OnUnload(*) {
    StopMacro()
    SaveCfgFile()
}

SetTrayMenu() {
    global mainGui, TITLE
    A_TrayMenu.Delete()
    A_TrayMenu.Add("设置", (*) => mainGui.Show())
    A_TrayMenu.Add("退出", (*) => ExitApp())
    A_TrayMenu.Tip := TITLE
}

CreateGui() {
    global mainGui, controls, skillControls, profileNames, currentProfile, general
    global actionItems, methodItems, startItems, startModeItems, quickPauseClickItems, quickPauseButtonItems, quickPauseActionItems, movingItems, potionItems, skillLabels
    mainGui := Gui("+MinSize980x570", TITLE)
    mainGui.SetFont("s9", "Segoe UI")
    mainGui.OnEvent("Close", (*) => GuiClose())

    mainGui.Add("Text", "x10 y12 w80", "当前配置：")
    controls["profile"] := mainGui.Add("DropDownList", "x90 y8 w150", profileNames)
    controls["profile"].Value := currentProfile
    controls["profile"].OnEvent("Change", (*) => OnProfileChanged())
    mainGui.Add("Button", "x250 y7 w80", "保存").OnEvent("Click", (*) => SaveCfgFile())

    mainGui.Add("GroupBox", "x10 y42 w610 h260", "按键宏设置")
    mainGui.Add("Text", "x130 y68 w60 Center", "快捷键")
    mainGui.Add("Text", "x205 y68 w85 Center", "策略")
    mainGui.Add("Text", "x310 y68 w95 Center", "间隔(ms)")
    mainGui.Add("Text", "x420 y68 w80 Center", "延迟(ms)")
    mainGui.Add("Text", "x530 y68 w50 Center", "随机")

    Loop 6 {
        idx := A_Index
        y := 92 + (idx - 1) * 34
        row := Map()
        mainGui.Add("Text", Format("x25 y{} w70 Center", y + 3), skillLabels[idx])
        row["customHotkey"] := mainGui.Add("Checkbox", Format("x103 y{} w25 h20", y + 3))
        if (idx <= 4) {
            row["customHotkey"].Visible := false
            row["customHotkey"].Value := 1
            row["hotkey"] := mainGui.Add("Hotkey", Format("x130 y{} w65", y))
        } else {
            row["hotkey"] := mainGui.Add("Hotkey", Format("x130 y{} w65", y))
        }
        row["action"] := mainGui.Add("DropDownList", Format("x205 y{} w85", y), actionItems)
        row["interval"] := mainGui.Add("Edit", Format("x315 y{} w70 Number", y))
        row["delay"] := mainGui.Add("Edit", Format("x425 y{} w70 Number", y))
        row["random"] := mainGui.Add("Checkbox", Format("x545 y{} w30 h20", y + 3))
        row["customHotkey"].OnEvent("Click", (*) => OnSkillControlChanged())
        row["action"].OnEvent("Change", (*) => OnSkillControlChanged())
        row["interval"].OnEvent("Change", (*) => OnSkillControlChanged())
        row["delay"].OnEvent("Change", (*) => OnSkillControlChanged())
        row["random"].OnEvent("Click", (*) => OnSkillControlChanged())
        skillControls.Push(row)
    }

    mainGui.Add("GroupBox", "x10 y312 w610 h205", "额外设置")
    mainGui.Add("Text", "x30 y340 w120", "快速切换至本配置：")
    controls["profileMethod"] := mainGui.Add("DropDownList", "x155 y336 w90", methodItems)
    controls["profileHotkey"] := mainGui.Add("Hotkey", "x255 y336 w95")
    controls["autoStart"] := mainGui.Add("Checkbox", "x365 y339 w150", "切换后自动启动宏")

    mainGui.Add("Text", "x30 y374 w90", "宏启动方式：")
    controls["startMode"] := mainGui.Add("DropDownList", "x120 y370 w95", startModeItems)
    controls["useSkillQueue"] := mainGui.Add("Checkbox", "x230 y374 w160", "使用按键队列(ms)：")
    controls["skillQueueInterval"] := mainGui.Add("Edit", "x390 y370 w55 Number")

    controls["enableQuickPause"] := mainGui.Add("Checkbox", "x30 y408 w95", "快速暂停：")
    controls["quickPauseMethod1"] := mainGui.Add("DropDownList", "x130 y404 w60", quickPauseClickItems)
    controls["quickPauseMethod2"] := mainGui.Add("DropDownList", "x195 y404 w80", quickPauseButtonItems)
    mainGui.Add("Text", "x282 y408 w20", "则")
    controls["quickPauseMethod3"] := mainGui.Add("DropDownList", "x305 y404 w150", quickPauseActionItems)
    controls["quickPauseDelay"] := mainGui.Add("Edit", "x465 y404 w55 Number")
    mainGui.Add("Text", "x525 y408 w35", "毫秒")

    mainGui.Add("Text", "x30 y442 w70", "走位辅助：")
    controls["movingMethod"] := mainGui.Add("DropDownList", "x105 y438 w150", movingItems)
    controls["movingInterval"] := mainGui.Add("Edit", "x270 y438 w55 Number")
    mainGui.Add("Text", "x330 y442 w65", "毫秒")

    mainGui.Add("Text", "x30 y476 w70", "药水辅助：")
    controls["potionMethod"] := mainGui.Add("DropDownList", "x105 y472 w120", potionItems)
    controls["potionInterval"] := mainGui.Add("Edit", "x240 y472 w55 Number")
    mainGui.Add("Text", "x300 y476 w65", "毫秒")

    mainGui.Add("GroupBox", "x650 y42 w310 h250", "通用设置")
    controls["soundOnProfileSwitch"] := mainGui.Add("Checkbox", "x670 y72 w230", "快捷键切换配置成功时播放声音")
    controls["smartPause"] := mainGui.Add("Checkbox", "x670 y104 w230", "智能暂停")
    controls["customStanding"] := mainGui.Add("Checkbox", "x670 y138 w150", "自定义强制站立键：")
    controls["customStandingHK"] := mainGui.Add("Hotkey", "x825 y134 w80")
    controls["customMoving"] := mainGui.Add("Checkbox", "x670 y172 w150", "自定义强制走位键：")
    controls["customMovingHK"] := mainGui.Add("Hotkey", "x825 y168 w80")
    controls["customPotion"] := mainGui.Add("Checkbox", "x670 y206 w150", "自定义药水键：")
    controls["customPotionHK"] := mainGui.Add("Hotkey", "x825 y202 w80")

    mainGui.Add("GroupBox", "x650 y312 w310 h105", "战斗宏")
    mainGui.Add("Text", "x670 y342 w115", "启动快捷键：")
    controls["startMethod"] := mainGui.Add("DropDownList", "x770 y338 w95", startItems)
    controls["startHotkey"] := mainGui.Add("Hotkey", "x875 y338 w70")
    mainGui.Add("Text", "x670 y380 w95", "发送模式：")
    controls["sendModeText"] := mainGui.Add("Text", "x770 y380 w120 cRed", general["sendmode"])

    mainGui.Add("Text", "x650 y485 w300", "D4KeyHelper AutoHotkey v2")
    mainGui.Add("Text", "x650 y510 w300", "原作者：Oldsand")
    mainGui.Add("Text", "x650 y535 w300", "by slime7")

    for _, ctrlName in ["profileMethod", "profileHotkey", "startMode", "skillQueueInterval"
        , "quickPauseMethod1", "quickPauseMethod2", "quickPauseMethod3", "quickPauseDelay"
        , "movingMethod", "movingInterval", "potionMethod", "potionInterval"] {
        controls[ctrlName].OnEvent("Change", (*) => OnProfileControlChanged())
    }
    for _, ctrlName in ["autoStart", "useSkillQueue", "enableQuickPause"] {
        controls[ctrlName].OnEvent("Click", (*) => OnProfileControlChanged())
    }
    for _, ctrlName in ["soundOnProfileSwitch", "smartPause", "customStanding", "customMoving", "customPotion"] {
        controls[ctrlName].OnEvent("Click", (*) => OnGeneralControlChanged())
    }
    for _, ctrlName in ["customStandingHK", "customMovingHK", "customPotionHK", "startMethod", "startHotkey"] {
        controls[ctrlName].OnEvent("Change", (*) => OnGeneralControlChanged())
    }
}

ReadCfgFile() {
    global profiles, profileNames, currentProfile, general
    general := Map(
        "gameonly", IntegerOrDefault(ReadIni("General", "gameonly", 1), 1),
        "enablesmartpause", IntegerOrDefault(ReadIni("General", "enablesmartpause", 1), 1),
        "enablesoundplay", IntegerOrDefault(ReadIni("General", "enablesoundplay", 1), 1),
        "startmethod", IntegerOrDefault(ReadIni("General", "startmethod", 7), 7),
        "starthotkey", ReadIni("General", "starthotkey", "F2"),
        "custommoving", IntegerOrDefault(ReadIni("General", "custommoving", 0), 0),
        "custommovinghk", ReadIni("General", "custommovinghk", "e"),
        "customstanding", IntegerOrDefault(ReadIni("General", "customstanding", 0), 0),
        "customstandinghk", ReadIni("General", "customstandinghk", "LShift"),
        "custompotion", IntegerOrDefault(ReadIni("General", "custompotion", 0), 0),
        "custompotionhk", ReadIni("General", "custompotionhk", "q"),
        "gamegamma", FloatOrDefault(ReadIni("General", "gamegamma", 1.0), 1.0),
        "sendmode", ReadIni("General", "sendmode", "Event"),
        "buffreferencewidth", IntegerOrDefault(ReadIni("General", "buffreferencewidth", 3440), 3440),
        "buffreferenceheight", IntegerOrDefault(ReadIni("General", "buffreferenceheight", 1440), 1440),
        "buffgreenactive", IntegerOrDefault(ReadIni("General", "buffgreenactive", 95), 95),
        "buffx_1", IntegerOrDefault(ReadIni("General", "buffx_1", 1260), 1260),
        "buffx_2", IntegerOrDefault(ReadIni("General", "buffx_2", 1364), 1364),
        "buffx_3", IntegerOrDefault(ReadIni("General", "buffx_3", 1467), 1467),
        "buffx_4", IntegerOrDefault(ReadIni("General", "buffx_4", 1571), 1571),
        "buffx_5", IntegerOrDefault(ReadIni("General", "buffx_5", 1676), 1676),
        "buffx_6", IntegerOrDefault(ReadIni("General", "buffx_6", 1785), 1785),
        "buffy_1", IntegerOrDefault(ReadIni("General", "buffy_1", 944), 944),
        "buffy_2", IntegerOrDefault(ReadIni("General", "buffy_2", 944), 944),
        "buffy_3", IntegerOrDefault(ReadIni("General", "buffy_3", 944), 944),
        "buffy_4", IntegerOrDefault(ReadIni("General", "buffy_4", 944), 944),
        "buffy_5", IntegerOrDefault(ReadIni("General", "buffy_5", 944), 944),
        "buffy_6", IntegerOrDefault(ReadIni("General", "buffy_6", 944), 944),
        "runonstart", IntegerOrDefault(ReadIni("General", "runonstart", 1), 1),
        "gameresolution", ReadIni("General", "gameresolution", "Auto")
    )
    general["gamegamma"] := Min(1.5, Max(0.5, general["gamegamma"]))
    currentProfile := IntegerOrDefault(ReadIni("General", "activatedprofile", 1), 1)

    sections := GetProfileSections()
    if (sections.Length = 0) {
        sections := ["配置1", "配置2", "配置3", "配置4"]
    }
    profiles := []
    profileNames := []
    for _, section in sections {
        profileNames.Push(section)
        profiles.Push(ReadProfile(section))
    }
    if (currentProfile < 1 || currentProfile > profiles.Length) {
        currentProfile := 1
    }
}

GetProfileSections() {
    sections := []
    raw := ReadConfigText()
    for _, line in StrSplit(raw, "`n", "`r") {
        line := Trim(line)
        if !RegExMatch(line, "^\[(.*)\]$", &match) {
            continue
        }
        section := NormalizeProfileSectionName(match[1])
        if (section != "" && section != "General") {
            sections.Push(section)
        }
    }
    return sections
}

ReadProfile(section) {
    profile := Map()
    profile["name"] := section
    profile["skills"] := []
    Loop 6 {
        idx := A_Index
        defaultHotkey := idx <= 4 ? String(idx) : (idx = 5 ? "LButton" : "RButton")
        profile["skills"].Push(Map(
            "hotkey", ReadIni(section, "skill_" idx, defaultHotkey),
            "customhotkey", IntegerOrDefault(ReadIni(section, "customhotkey_" idx, idx <= 4 ? 1 : 0), idx <= 4 ? 1 : 0),
            "action", IntegerOrDefault(ReadIni(section, "action_" idx, 1), 1),
            "interval", IntegerOrDefault(ReadIni(section, "interval_" idx, 300), 300),
            "delay", IntegerOrDefault(ReadIni(section, "delay_" idx, 10), 10),
            "random", IntegerOrDefault(ReadIni(section, "random_" idx, 1), 1),
            "priority", IntegerOrDefault(ReadIni(section, "priority_" idx, 1), 1),
            "repeat", IntegerOrDefault(ReadIni(section, "repeat_" idx, 1), 1),
            "repeatinterval", IntegerOrDefault(ReadIni(section, "repeatinterval_" idx, 30), 30),
            "triggerbutton", ReadIni(section, "triggerbutton_" idx, "LButton")
        ))
    }
    profile["profilemethod"] := IntegerOrDefault(ReadIni(section, "profilehkmethod", 1), 1)
    profile["profilehotkey"] := ReadIni(section, "profilehkkey", "")
    profile["movingmethod"] := IntegerOrDefault(ReadIni(section, "movingmethod", 1), 1)
    profile["movinginterval"] := IntegerOrDefault(ReadIni(section, "movinginterval", 100), 100)
    profile["potionmethod"] := IntegerOrDefault(ReadIni(section, "potionmethod", 1), 1)
    profile["potioninterval"] := IntegerOrDefault(ReadIni(section, "potioninterval", 500), 500)
    profile["lazymode"] := IntegerOrDefault(ReadIni(section, "lazymode", 1), 1)
    profile["enablequickpause"] := IntegerOrDefault(ReadIni(section, "enablequickpause", 0), 0)
    profile["quickpausemethod1"] := IntegerOrDefault(ReadIni(section, "quickpausemethod1", 1), 1)
    profile["quickpausemethod2"] := IntegerOrDefault(ReadIni(section, "quickpausemethod2", 1), 1)
    profile["quickpausemethod3"] := IntegerOrDefault(ReadIni(section, "quickpausemethod3", 1), 1)
    profile["quickpausedelay"] := IntegerOrDefault(ReadIni(section, "quickpausedelay", 1500), 1500)
    profile["useskillqueue"] := IntegerOrDefault(ReadIni(section, "useskillqueue", 0), 0)
    profile["useskillqueueinterval"] := IntegerOrDefault(ReadIni(section, "useskillqueueinterval", 200), 200)
    profile["autostartmarco"] := IntegerOrDefault(ReadIni(section, "autostartmarco", 0), 0)
    return profile
}

ReadIni(section, key, defaultValue) {
    raw := ReadConfigText()
    currentSection := ""
    for _, line in StrSplit(raw, "`n", "`r") {
        line := Trim(line)
        if (line = "" || SubStr(line, 1, 1) = ";") {
            continue
        }
        if RegExMatch(line, "^\[(.*)\]$", &sectionMatch) {
            currentSection := NormalizeProfileSectionName(sectionMatch[1])
            continue
        }
        if (currentSection != section) {
            continue
        }
        delimiterPos := InStr(line, "=")
        if !delimiterPos {
            continue
        }
        currentKey := Trim(SubStr(line, 1, delimiterPos - 1))
        if (currentKey = key) {
            return SubStr(line, delimiterPos + 1)
        }
    }
    return defaultValue
}

SaveCfgFile() {
    global profiles, profileNames, currentProfile, general, CONFIG_FILE, VERSION
    SaveControlsToState()
    output := "; ===============================================`r`n"
    output .= "; D4KeyHelper AutoHotkey v2 配置文件`r`n"
    output .= "; ===============================================`r`n"
    output .= "[General]`r`n"
    WriteIniLine(&output, "version", VERSION)
    WriteIniLine(&output, "activatedprofile", currentProfile)
    for key, value in general {
        WriteIniLine(&output, key, value)
    }
    for index, profile in profiles {
        section := NormalizeProfileSectionName(profileNames[index])
        output .= "[" section "]`r`n"
        Loop 6 {
            skill := profile["skills"][A_Index]
            WriteIniLine(&output, "action_" A_Index, skill["action"])
            WriteIniLine(&output, "interval_" A_Index, skill["interval"])
            WriteIniLine(&output, "delay_" A_Index, skill["delay"])
            WriteIniLine(&output, "random_" A_Index, skill["random"])
            WriteIniLine(&output, "customhotkey_" A_Index, skill["customhotkey"])
            WriteIniLine(&output, "priority_" A_Index, skill["priority"])
            WriteIniLine(&output, "repeat_" A_Index, skill["repeat"])
            WriteIniLine(&output, "repeatinterval_" A_Index, skill["repeatinterval"])
            WriteIniLine(&output, "triggerbutton_" A_Index, skill["triggerbutton"])
            if (A_Index <= 4 || skill["customhotkey"]) {
                WriteIniLine(&output, "skill_" A_Index, skill["hotkey"])
            }
        }
        WriteIniLine(&output, "profilehkmethod", profile["profilemethod"])
        WriteIniLine(&output, "profilehkkey", profile["profilehotkey"])
        WriteIniLine(&output, "movingmethod", profile["movingmethod"])
        WriteIniLine(&output, "movinginterval", profile["movinginterval"])
        WriteIniLine(&output, "potionmethod", profile["potionmethod"])
        WriteIniLine(&output, "potioninterval", profile["potioninterval"])
        WriteIniLine(&output, "lazymode", profile["lazymode"])
        WriteIniLine(&output, "enablequickpause", profile["enablequickpause"])
        WriteIniLine(&output, "quickpausemethod1", profile["quickpausemethod1"])
        WriteIniLine(&output, "quickpausemethod2", profile["quickpausemethod2"])
        WriteIniLine(&output, "quickpausemethod3", profile["quickpausemethod3"])
        WriteIniLine(&output, "quickpausedelay", profile["quickpausedelay"])
        WriteIniLine(&output, "useskillqueue", profile["useskillqueue"])
        WriteIniLine(&output, "useskillqueueinterval", profile["useskillqueueinterval"])
        WriteIniLine(&output, "autostartmarco", profile["autostartmarco"])
    }
    cfgFile := FileOpen(CONFIG_FILE, "w", "UTF-8-RAW")
    cfgFile.Write(output)
    cfgFile.Close()
}

ReadConfigText() {
    global CONFIG_FILE
    if !FileExist(CONFIG_FILE) {
        return ""
    }
    try {
        return FileRead(CONFIG_FILE, "UTF-8")
    } catch {
        return ""
    }
}

WriteIniLine(&output, key, value) {
    output .= key "=" value "`r`n"
}

NormalizeProfileSectionName(section) {
    section := Trim(section)
    if RegExMatch(section, "^配置(\d+)$", &match) {
        return "配置" match[1]
    }
    if RegExMatch(section, "^[�\?]+(\d+)$", &match) {
        return "配置" match[1]
    }
    return section
}

LoadProfileToControls(profileIndex) {
    global controls, skillControls, profiles, general
    global actionItems, methodItems, startModeItems, quickPauseClickItems, quickPauseButtonItems, quickPauseActionItems, movingItems, potionItems, startItems
    profile := profiles[profileIndex]
    controls["profile"].Value := profileIndex
    Loop 6 {
        skill := profile["skills"][A_Index]
        customHotkey := A_Index <= 4 ? 1 : skill["customhotkey"]
        skillControls[A_Index]["customHotkey"].Value := customHotkey
        skillControls[A_Index]["hotkey"].Value := customHotkey ? skill["hotkey"] : GetDefaultSkillHotkey(A_Index)
        skillControls[A_Index]["action"].Value := ClampIndex(skill["action"], actionItems.Length)
        skillControls[A_Index]["interval"].Value := skill["interval"]
        skillControls[A_Index]["delay"].Value := skill["delay"]
        skillControls[A_Index]["random"].Value := skill["random"]
    }
    controls["profileMethod"].Value := ClampIndex(profile["profilemethod"], methodItems.Length)
    controls["profileHotkey"].Value := profile["profilehotkey"]
    controls["autoStart"].Value := profile["autostartmarco"]
    controls["startMode"].Value := ClampIndex(profile["lazymode"], startModeItems.Length)
    controls["useSkillQueue"].Value := profile["useskillqueue"]
    controls["skillQueueInterval"].Value := profile["useskillqueueinterval"]
    controls["enableQuickPause"].Value := profile["enablequickpause"]
    controls["quickPauseMethod1"].Value := ClampIndex(profile["quickpausemethod1"], quickPauseClickItems.Length)
    controls["quickPauseMethod2"].Value := ClampIndex(profile["quickpausemethod2"], quickPauseButtonItems.Length)
    controls["quickPauseMethod3"].Value := ClampIndex(profile["quickpausemethod3"], quickPauseActionItems.Length)
    controls["quickPauseDelay"].Value := profile["quickpausedelay"]
    controls["movingMethod"].Value := ClampIndex(profile["movingmethod"], movingItems.Length)
    controls["movingInterval"].Value := profile["movinginterval"]
    controls["potionMethod"].Value := ClampIndex(profile["potionmethod"], potionItems.Length)
    controls["potionInterval"].Value := profile["potioninterval"]

    controls["soundOnProfileSwitch"].Value := general["enablesoundplay"]
    controls["smartPause"].Value := general["enablesmartpause"]
    controls["customStanding"].Value := general["customstanding"]
    controls["customStandingHK"].Value := general["customstandinghk"]
    controls["customMoving"].Value := general["custommoving"]
    controls["customMovingHK"].Value := general["custommovinghk"]
    controls["customPotion"].Value := general["custompotion"]
    controls["customPotionHK"].Value := general["custompotionhk"]
    controls["startMethod"].Value := ClampIndex(general["startmethod"], startItems.Length)
    controls["startHotkey"].Value := general["starthotkey"]
    UpdateControlStates()
}

SaveControlsToState() {
    global profiles, currentProfile, controls, skillControls, general
    profile := profiles[currentProfile]
    Loop 6 {
        skill := profile["skills"][A_Index]
        customHotkey := A_Index <= 4 ? 1 : skillControls[A_Index]["customHotkey"].Value
        skill["customhotkey"] := customHotkey
        if (customHotkey) {
            skill["hotkey"] := skillControls[A_Index]["hotkey"].Value
        } else {
            skill["hotkey"] := GetDefaultSkillHotkey(A_Index)
            skill["action"] := 1
            skillControls[A_Index]["hotkey"].Value := skill["hotkey"]
            skillControls[A_Index]["action"].Value := 1
            continue
        }
        skill["action"] := skillControls[A_Index]["action"].Value
        skill["interval"] := IntegerOrDefault(skillControls[A_Index]["interval"].Value, 300)
        skill["delay"] := IntegerOrDefault(skillControls[A_Index]["delay"].Value, 0)
        skill["random"] := skillControls[A_Index]["random"].Value
    }
    profile["profilemethod"] := controls["profileMethod"].Value
    profile["profilehotkey"] := controls["profileHotkey"].Value
    profile["autostartmarco"] := controls["autoStart"].Value
    profile["lazymode"] := controls["startMode"].Value
    profile["useskillqueue"] := controls["useSkillQueue"].Value
    profile["useskillqueueinterval"] := IntegerOrDefault(controls["skillQueueInterval"].Value, 200)
    profile["enablequickpause"] := controls["enableQuickPause"].Value
    profile["quickpausemethod1"] := controls["quickPauseMethod1"].Value
    profile["quickpausemethod2"] := controls["quickPauseMethod2"].Value
    profile["quickpausemethod3"] := controls["quickPauseMethod3"].Value
    profile["quickpausedelay"] := IntegerOrDefault(controls["quickPauseDelay"].Value, 1500)
    profile["movingmethod"] := controls["movingMethod"].Value
    profile["movinginterval"] := IntegerOrDefault(controls["movingInterval"].Value, 100)
    profile["potionmethod"] := controls["potionMethod"].Value
    profile["potioninterval"] := IntegerOrDefault(controls["potionInterval"].Value, 500)

    general["enablesoundplay"] := controls["soundOnProfileSwitch"].Value
    general["enablesmartpause"] := controls["smartPause"].Value
    general["customstanding"] := controls["customStanding"].Value
    general["customstandinghk"] := controls["customStandingHK"].Value != "" ? controls["customStandingHK"].Value : "LShift"
    general["custommoving"] := controls["customMoving"].Value
    general["custommovinghk"] := controls["customMovingHK"].Value != "" ? controls["customMovingHK"].Value : "e"
    general["custompotion"] := controls["customPotion"].Value
    general["custompotionhk"] := controls["customPotionHK"].Value != "" ? controls["customPotionHK"].Value : "q"
    general["startmethod"] := controls["startMethod"].Value
    general["starthotkey"] := controls["startHotkey"].Value
}

OnProfileChanged() {
    global currentProfile, controls
    SaveControlsToState()
    currentProfile := controls["profile"].Value
    LoadProfileToControls(currentProfile)
    RegisterAllHotkeys()
}

OnProfileControlChanged() {
    SaveControlsToState()
    UpdateControlStates()
    RegisterAllHotkeys()
}

OnSkillControlChanged() {
    SaveControlsToState()
    UpdateSkillControlStates()
}

OnGeneralControlChanged() {
    SaveControlsToState()
    UpdateControlStates()
    RegisterAllHotkeys()
}

UpdateControlStates() {
    global controls
    controls["profileHotkey"].Enabled := controls["profileMethod"].Value = 7
    controls["autoStart"].Enabled := controls["profileMethod"].Value != 1
    controls["skillQueueInterval"].Enabled := controls["useSkillQueue"].Value = 1
    controls["quickPauseMethod1"].Enabled := controls["enableQuickPause"].Value = 1
    controls["quickPauseMethod2"].Enabled := controls["enableQuickPause"].Value = 1
    controls["quickPauseMethod3"].Enabled := controls["enableQuickPause"].Value = 1
    controls["quickPauseDelay"].Enabled := controls["enableQuickPause"].Value = 1 && controls["quickPauseMethod1"].Value != 3
    controls["movingInterval"].Enabled := controls["movingMethod"].Value = 4
    controls["potionInterval"].Enabled := controls["potionMethod"].Value > 1
    controls["customStandingHK"].Enabled := controls["customStanding"].Value = 1
    controls["customMovingHK"].Enabled := controls["customMoving"].Value = 1
    controls["customPotionHK"].Enabled := controls["customPotion"].Value = 1
    controls["startHotkey"].Enabled := controls["startMethod"].Value = 7
    UpdateSkillControlStates()
}

UpdateSkillControlStates() {
    global skillControls
    Loop 6 {
        customHotkey := A_Index <= 4 ? 1 : skillControls[A_Index]["customHotkey"].Value
        if (!customHotkey) {
            skillControls[A_Index]["hotkey"].Value := GetDefaultSkillHotkey(A_Index)
            skillControls[A_Index]["action"].Value := 1
        }
        action := skillControls[A_Index]["action"].Value
        skillControls[A_Index]["hotkey"].Enabled := customHotkey
        skillControls[A_Index]["action"].Enabled := customHotkey
        skillControls[A_Index]["interval"].Enabled := customHotkey && (action = 3 || action = 4)
        skillControls[A_Index]["delay"].Enabled := customHotkey && (action = 3 || action = 5)
        skillControls[A_Index]["random"].Enabled := customHotkey && (action = 3 || action = 5)
    }
}

RegisterAllHotkeys() {
    RegisterStartHotkey()
    RegisterProfileHotkeys()
    RegisterQuickPauseHotkey()
}

RegisterStartHotkey() {
    global startRunHK, general, startMethodKeys
    if (startRunHK != "") {
        TryHotkey("~*" startRunHK, "Off")
    }
    method := ClampIndex(general["startmethod"], startMethodKeys.Length)
    startRunHK := method = 7 ? general["starthotkey"] : startMethodKeys[method]
    if (startRunHK != "") {
        TryHotkey("~*" startRunHK, (*) => MainMacro(), "On")
    }
}

RegisterProfileHotkeys() {
    global profileKeybinding, profiles, mouseMethodKeys
    for key, _ in profileKeybinding {
        TryHotkey("~*" key, "Off")
    }
    profileKeybinding := Map()
    for index, profile in profiles {
        method := ClampIndex(profile["profilemethod"], mouseMethodKeys.Length)
        key := method = 7 ? profile["profilehotkey"] : mouseMethodKeys[method]
        if (key != "") {
            profileKeybinding[key] := index
            TryHotkey("~*" key, (*) => SwitchProfile(), "On")
        }
    }
}

RegisterQuickPauseHotkey() {
    global quickPauseHK, quickPauseKeys, profiles, currentProfile
    if (quickPauseHK != "") {
        TryHotkey("~*" quickPauseHK, "Off")
    }
    profile := profiles[currentProfile]
    if (profile["enablequickpause"]) {
        quickPauseHK := quickPauseKeys[ClampIndex(profile["quickpausemethod2"], quickPauseKeys.Length)]
        TryHotkey("~*" quickPauseHK, (*) => QuickPause(), "On")
    } else {
        quickPauseHK := ""
    }
}

TryHotkey(key, action, options := "") {
    try {
        if (options = "") {
            Hotkey(key, action)
        } else {
            Hotkey(key, action, options)
        }
    }
}

MainMacro() {
    global profiles, currentProfile, startRunHK, vRunning
    if !IsAllowedWindow() {
        return
    }
    SaveControlsToState()
    mode := profiles[currentProfile]["lazymode"]
    switch mode {
        case 1:
            if !vRunning {
                RunMacro()
            } else {
                StopMacro()
            }
        case 2:
            RunMacro()
            if (startRunHK != "") {
                KeyWait(startRunHK)
            }
            StopMacro()
        case 3:
            profile := profiles[currentProfile]
            Loop 6 {
                skill := profile["skills"][A_Index]
                if (skill["action"] = 2) {
                    Send "{" GetSkillHotkey(A_Index) "}"
                }
            }
    }
}

RunMacro() {
    global vRunning, vPausing, skillQueue, syncTimer, syncDelay, keysOnHold
    global forceStandingKey, forceMovingKey, potionKey, gameW, gameH, gameX, gameY
    global profiles, currentProfile, general, skillTimers, movingTimerFn, potionTimerFn, queueTimerFn, triggerHotkeys
    if !IsAllowedWindow() {
        return
    }
    SaveControlsToState()
    if !GetGameResolution(&gameW, &gameH) {
        return
    }
    pos := GetGameXYOnScreen(0, 0)
    gameX := pos[1]
    gameY := pos[2]
    forceStandingKey := general["customstanding"] ? general["customstandinghk"] : "LShift"
    forceMovingKey := general["custommoving"] ? general["custommovinghk"] : "e"
    potionKey := general["custompotion"] ? general["custompotionhk"] : "q"
    skillQueue := []
    syncTimer := Map()
    syncDelay := Map()
    keysOnHold := Map()
    profile := profiles[currentProfile]
    vRunning := true
    vPausing := false

    StopSkillTimers()
    Loop 6 {
        idx := A_Index
        skill := profile["skills"][idx]
        switch skill["action"] {
            case 2:
                key := GetSkillHotkey(idx)
                Send "{" key " Down}"
                keysOnHold[key] := true
            case 3, 4:
                fn := SkillCallback(idx)
                skillTimers[idx] := fn
                if (general["runonstart"]) {
                    SetTimer(fn, -1)
                }
                SetTimer(fn, Max(20, skill["interval"]))
            case 5:
                key := skill["triggerbutton"]
                triggerHotkeys[idx] := key
                TryHotkey("~*" key, SkillCallback(idx), "On")
        }
    }

    switch profile["movingmethod"] {
        case 2:
            Send "{" forceStandingKey " Down}"
            keysOnHold[forceStandingKey] := true
        case 3:
            Send "{" forceMovingKey " Down}"
            keysOnHold[forceMovingKey] := true
        case 4:
            movingTimerFn := (*) => ForceMoving()
            if (general["runonstart"]) {
                ForceMoving()
            }
            SetTimer(movingTimerFn, Max(20, profile["movinginterval"]))
    }

    if (profile["potionmethod"] > 1) {
        potionTimerFn := (*) => PotionHelper(profile["potionmethod"])
        SetTimer(potionTimerFn, Max(200, profile["potioninterval"]))
    }
    if (profile["useskillqueue"]) {
        queueTimerFn := (*) => SpamSkillQueue(profile["useskillqueueinterval"])
        if (general["runonstart"]) {
            SetTimer(queueTimerFn, -1)
        }
        SetTimer(queueTimerFn, Max(50, profile["useskillqueueinterval"]))
    }
}

StopMacro() {
    global vRunning, vPausing, keysOnHold, skillQueue, movingTimerFn, potionTimerFn, queueTimerFn
    StopSkillTimers()
    if IsSet(movingTimerFn) && movingTimerFn != "" {
        SetTimer(movingTimerFn, 0)
    }
    if IsSet(potionTimerFn) && potionTimerFn != "" {
        SetTimer(potionTimerFn, 0)
    }
    if IsSet(queueTimerFn) && queueTimerFn != "" {
        SetTimer(queueTimerFn, 0)
    }
    for key, _ in keysOnHold {
        if GetKeyState(key) {
            Send "{" key " Up}"
        }
    }
    keysOnHold := Map()
    skillQueue := []
    vRunning := false
    vPausing := false
}

StopSkillTimers() {
    global skillTimers, triggerHotkeys
    for _, fn in skillTimers {
        SetTimer(fn, 0)
    }
    skillTimers := Map()
    for _, key in triggerHotkeys {
        TryHotkey("~*" key, "Off")
    }
    triggerHotkeys := Map()
}

SkillCallback(nskill) {
    return (*) => SkillKey(nskill)
}

SkillKey(nskill) {
    global profiles, currentProfile, vPausing, vRunning, skillQueue, syncTimer, syncDelay
    global gameW, gameH, forceStandingKey, general
    if (vPausing || !vRunning) {
        return
    }
    profile := profiles[currentProfile]
    skill := profile["skills"][nskill]
    Loop 6 {
        other := profile["skills"][A_Index]
        if (A_Index = nskill) {
            continue
        }
        if (other["action"] = 4 && other["priority"] > skill["priority"]) {
            xy := GetSkillButtonBuffPos(gameW, gameH, A_Index)
            rgb := GetPixelRGB(xy)
            if (rgb[2] >= general["buffgreenactive"]) {
                return
            }
        }
    }

    key := GetSkillHotkey(nskill)
    switch skill["action"] {
        case 3, 5:
            ApplySkillDelay(nskill, skill)
            Loop Max(1, skill["repeat"]) {
                if (profile["useskillqueue"]) {
                    if (skillQueue.Length < 1000) {
                        skillQueue.InsertAt(1, [key, 3])
                    }
                } else {
                    Send "{Blind}{" key "}"
                }
                if (skill["repeat"] > 1) {
                    Sleep(Max(1, skill["repeatinterval"]))
                }
            }
        case 4:
            xy := GetSkillButtonBuffPos(gameW, gameH, nskill)
            rgb := GetPixelRGB(xy)
            if (rgb[2] < general["buffgreenactive"]) {
                if (profile["useskillqueue"]) {
                    if (skillQueue.Length < 1000) {
                        skillQueue.Push([key, 4])
                    }
                } else if (nskill = 5 && !GetKeyState(forceStandingKey)) {
                    Send "{Blind}{" forceStandingKey " Down}{" key " Down}"
                    Send "{Blind}{" key " Up}{" forceStandingKey " Up}"
                } else {
                    Send "{Blind}{" key "}"
                }
            }
    }
}

ApplySkillDelay(nskill, skill) {
    global syncTimer, syncDelay
    rawDelay := skill["delay"]
    if (Abs(rawDelay) <= 20) {
        return
    }
    if (skill["random"]) {
        delay := Random(10, Abs(rawDelay))
    } else {
        delay := Abs(rawDelay)
    }
    if (rawDelay < 0) {
        delay := Max(0, skill["interval"] - delay)
    }
    syncDelay[nskill] := delay
    syncTimer[nskill] := A_TickCount
    while (A_TickCount - syncTimer[nskill] <= syncDelay[nskill]) {
        Sleep(10)
    }
}

SpamSkillQueue(interval) {
    global skillQueue, forceStandingKey, keysOnHold
    while (skillQueue.Length > 0) {
        item := skillQueue.RemoveAt(1)
        key := item[1]
        reason := item[2]
        if (reason = 3) {
            for holdKey, _ in keysOnHold {
                if GetKeyState(holdKey) {
                    Send "{" holdKey " Up}"
                }
            }
            Sleep(interval // 4)
        }
        if (!GetKeyState(forceStandingKey) && (reason = 3 || key = "LButton")) {
            Send "{Blind}{" forceStandingKey " Down}{" key " Down}"
            if (reason = 3) {
                Sleep(interval // 4)
            }
            Send "{Blind}{" key " Up}{" forceStandingKey " Up}"
        } else {
            Send "{" key "}"
        }
        if (reason = 3) {
            Sleep(interval // 4)
            for holdKey, _ in keysOnHold {
                if !GetKeyState(holdKey) {
                    Send "{" holdKey " Down}"
                }
            }
            break
        }
    }
}

PotionHelper(action) {
    global vPausing, potionKey, lastPotion, gameW, gameH
    if vPausing {
        return
    }
    switch action {
        case 2:
            Send "{" potionKey "}"
        case 3:
            currentPotion := GetPixelsRGB(Round(gameW / 2 - (3440 / 2 - 1822) * gameH / 1440), Round(1340 * gameH / 1440), Round(66 * gameH / 1440), Round(66 * gameH / 1440))
            if (lastPotion.Length && IsArraysEqual(lastPotion, currentPotion[1], 0)) {
                Send "{" potionKey "}"
            }
            lastPotion := currentPotion[1]
    }
}

ForceMoving() {
    global vPausing, forceMovingKey
    if !vPausing {
        Send "{" forceMovingKey "}"
    }
}

QuickPause() {
    global profiles, currentProfile
    profile := profiles[currentProfile]
    switch profile["quickpausemethod1"] {
        case 1:
            if (A_PriorHotkey = A_ThisHotkey && A_TimeSincePriorHotkey < DllCall("GetDoubleClickTime", "UInt")) {
                ClickPauseMacro(profile["quickpausedelay"], profile["quickpausemethod3"])
            }
        case 2:
            ClickPauseMacro(profile["quickpausedelay"], profile["quickpausemethod3"])
        case 3:
            ClickPauseMacro(-1, profile["quickpausemethod3"])
    }
}

ClickPauseMacro(pauseTime, pauseAction) {
    global vRunning, forceStandingKey, quickPauseHK
    if !vRunning {
        return
    }
    StopMacro()
    if (pauseTime > 0) {
        SetTimer((*) => RunMacro(), -pauseTime)
        if (pauseAction = 2) {
            startTime := A_TickCount
            while (A_TickCount - startTime < pauseTime) {
                ClickWithStandingReleased()
                Sleep(50)
            }
        }
    } else {
        Loop 1000 {
            if (pauseAction = 2) {
                ClickWithStandingReleased()
            }
            Sleep(50)
            if !GetKeyState(quickPauseHK, "P") {
                break
            }
        }
        SetTimer((*) => RunMacro(), -1)
    }
}

ClickWithStandingReleased() {
    global forceStandingKey
    if GetKeyState(forceStandingKey) {
        Send "{" forceStandingKey " Up}"
        Click()
        Send "{" forceStandingKey " Down}"
    } else {
        Click()
    }
}

SwitchProfile() {
    global profileKeybinding, currentProfile, controls, profiles, general, vRunning, vPausing
    key := RegExReplace(A_ThisHotkey, "[~*]")
    if !profileKeybinding.Has(key) {
        return
    }
    targetProfile := profileKeybinding[key]
    if (targetProfile = currentProfile) {
        return
    }
    wasRunning := vRunning
    wasPausing := vPausing
    StopMacro()
    SaveControlsToState()
    currentProfile := targetProfile
    LoadProfileToControls(currentProfile)
    if (general["enablesoundplay"]) {
        SoundBeep(750, 250)
    }
    if (wasRunning && !wasPausing && profiles[currentProfile]["autostartmarco"] && profiles[currentProfile]["lazymode"] = 1) {
        RunMacro()
    }
}

WatchActiveWindow() {
    global vRunning
    if (vRunning && !IsAllowedWindow()) {
        StopMacro()
    }
}

IsAllowedWindow() {
    global general, GAME_WINDOW
    if !general["gameonly"] {
        return true
    }
    return WinActive(GAME_WINDOW)
}

GetSkillHotkey(idx) {
    global profiles, currentProfile
    skill := profiles[currentProfile]["skills"][idx]
    if (idx >= 5 && !skill["customhotkey"]) {
        return GetDefaultSkillHotkey(idx)
    }
    return skill["hotkey"]
}

GetDefaultSkillHotkey(idx) {
    if (idx = 5) {
        return "LButton"
    }
    if (idx = 6) {
        return "RButton"
    }
    return String(idx)
}

GetSkillButtonBuffPos(width, height, buttonID) {
    global general
    static defaultX := [1260, 1364, 1467, 1571, 1676, 1785]
    refWidth := Max(1, IntegerOrDefault(general["buffreferencewidth"], 3440))
    refHeight := Max(1, IntegerOrDefault(general["buffreferenceheight"], 1440))
    refX := IntegerOrDefault(general["buffx_" buttonID], defaultX[buttonID])
    refY := IntegerOrDefault(general["buffy_" buttonID], 944)
    return [Round(width / 2 - (refWidth / 2 - refX) * height / refHeight), Round(refY * height / refHeight)]
}

GetGameXYOnScreen(x, y) {
    global general, GAME_WINDOW
    hwnd := WinExist(general["gameonly"] ? GAME_WINDOW : "A")
    point := Buffer(8, 0)
    NumPut("Int", x, point, 0)
    NumPut("Int", y, point, 4)
    DllCall("ClientToScreen", "Ptr", hwnd, "Ptr", point)
    return [NumGet(point, 0, "Int"), NumGet(point, 4, "Int")]
}

GetGameResolution(&width, &height) {
    global general, GAME_WINDOW
    if (general["gameresolution"] = "Auto") {
        hwnd := WinExist(general["gameonly"] ? GAME_WINDOW : "A")
        rect := Buffer(16, 0)
        DllCall("GetClientRect", "Ptr", hwnd, "Ptr", rect)
        width := NumGet(rect, 8, "Int")
        height := NumGet(rect, 12, "Int")
        if (width * height = 0 && general["gameonly"]) {
            MsgBox(Format("无法获取到游戏分辨率，错误代码：0x{:X}，请尝试切换至窗口模式运行游戏。", A_LastError))
            return false
        }
    } else {
        parts := StrSplit(general["gameresolution"], "x", A_Space)
        width := IntegerOrDefault(parts[1], 0)
        height := IntegerOrDefault(parts[2], 0)
        if (width <= 0 || height <= 0) {
            width := A_ScreenWidth
            height := A_ScreenHeight
        }
    }
    return true
}

GetPixelRGB(point) {
    color := PixelGetColor(point[1], point[2], "RGB")
    return SplitRGB(color)
}

GetPixelsRGB(pointX, pointY, width, height, aggFunc := "") {
    red := []
    green := []
    blue := []
    Loop width {
        x := A_Index - 1
        Loop height {
            y := A_Index - 1
            rgb := GetPixelRGB([pointX + x, pointY + y])
            red.Push(rgb[1])
            green.Push(rgb[2])
            blue.Push(rgb[3])
        }
    }
    if (aggFunc = "") {
        return [red, green, blue]
    }
    if (aggFunc = "Max") {
        return [Max(red*), Max(green*), Max(blue*)]
    }
    return [red, green, blue]
}

SplitRGB(color) {
    global general
    blue := color & 0xFF
    green := (color & 0xFF00) >> 8
    red := (color & 0xFF0000) >> 16
    gamma := Float(general["gamegamma"])
    if (Abs(gamma - 1) >= 0.01) {
        blue := ((blue / 255) ** (1.75 * gamma - 0.75)) * 255
        green := ((green / 255) ** (1.9 * gamma - 0.9)) * 255
        red := ((red / 255) ** (1.9 * gamma - 0.9)) * 255
    }
    return [red, green, blue]
}

IsArraysEqual(arrayA, arrayB, tolerance := 0) {
    if (arrayA.Length != arrayB.Length) {
        return false
    }
    for index, value in arrayA {
        if (Abs(value - arrayB[index]) > tolerance) {
            return false
        }
    }
    return true
}

ClampIndex(value, maxValue) {
    value := IntegerOrDefault(value, 1)
    if (value < 1) {
        return 1
    }
    if (value > maxValue) {
        return maxValue
    }
    return value
}

IntegerOrDefault(value, defaultValue) {
    try {
        return Integer(value)
    } catch {
        return defaultValue
    }
}

FloatOrDefault(value, defaultValue) {
    try {
        return Float(value)
    } catch {
        return defaultValue
    }
}

GuiClose() {
    global mainGui
    SaveCfgFile()
    mainGui.Hide()
}

#HotIf IsAllowedWindow()

~*Enter::
~*T::
~*M:: {
    global general
    if (general["enablesmartpause"]) {
        StopMacro()
    }
}

~*Tab:: {
    global vPausing, keysOnHold, general
    if !general["enablesmartpause"] {
        return
    }
    vPausing := !vPausing
    if vPausing {
        for key, _ in keysOnHold {
            if GetKeyState(key) {
                Send "{" key " Up}"
            }
        }
    } else {
        for key, _ in keysOnHold {
            if !GetKeyState(key) {
                Send "{" key " Down}"
            }
        }
    }
}

NumpadIns::Numpad0
NumpadEnd::Numpad1
NumpadDown::Numpad2
NumpadPgDn::Numpad3
NumpadLeft::Numpad4
NumpadClear::Numpad5
NumpadRight::Numpad6
NumpadHome::Numpad7
NumpadUp::Numpad8
NumpadPgUp::Numpad9
NumpadDel::NumpadDot

#HotIf
