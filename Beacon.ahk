#Requires AutoHotkey v2.0
#SingleInstance Off

; =============================================================================
;                      Beacon Tutorial and Keyboard Shortcuts System
;                      Version: 4.5 (Announce Commands)
;                      (Added Read&Write, MAGic, SuperNova, OSK, WSR, NaturalReader)
;                      (Ease of Access features guide; reorganized Accessibility menu)
;                      (Version notes on all major content; LibreOffice full coverage)
;
; Description:
;   An accessibility-first tutorial and keyboard shortcuts system for Windows.
;   Provides a centralized menu-based interface for organized shortcut reference
;   guides across applications, Windows features, web apps, and assistive tools.
;
; Features:
;   - Menu-driven interface accessible via Windows + Shift + H
;   - Support for application-specific shortcuts (Office, browsers, multimedia, etc.)
;   - Complete Office 365 Online shortcuts for all web applications
;   - Accessibility shortcuts reference (screen readers, magnifier, etc.)
;   - Enhanced dark mode theming for menus AND shortcut content dialogs
;   - Full keyboard navigation (arrow keys, Enter, Escape)
;   - Responsive mouse hover highlighting with blue selection indicator
;   - Automatic theme monitoring and switching
;   - Consistent UI with easy navigation
;   - Memory-efficient design
;   - Optimized for easier addition of new shortcut sections
;   - UPDATED: Borderless menu items for cleaner appearance
;   - NEW: Mouse hover support with synchronized keyboard/mouse navigation
;
; Usage:
;   Press Windows + Shift + H to bring up the shortcuts menu
;   Press Windows + Shift + K to auto-detect the focused app and show its shortcuts
;   Legacy fallback:
;     Backtick + 1 opens the menu; Backtick + 2 opens focus lookup
;     Backtick alone still types a literal backtick
;   Use arrow keys to navigate, Enter to select, Esc to close
;   Hover mouse over items for instant highlighting and selection
;
; Dependencies:
;   - AutoHotkey v2.0+
; =============================================================================

; =============================================================================
;                    ENHANCED DARK MODE SYSTEM (MENUS + DIALOGS)
; =============================================================================

; Function to detect if Windows is in dark mode
Beacon_IsWindowsDarkMode() {
    try {
        ; Check the registry for the current theme setting
        ; AppsUseLightTheme: 0 = Dark Mode, 1 = Light Mode
        lightTheme := RegRead("HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme")
        return (lightTheme == 0)
    } catch {
        ; If registry key doesn't exist, assume light mode
        return false
    }
}

; Function to detect if Windows high contrast mode is active
Beacon_IsWindowsHighContrastMode() {
    static SPI_GETHIGHCONTRAST := 0x0042
    static HCF_HIGHCONTRASTON := 0x00000001

    try {
        structSize := 8 + A_PtrSize
        hc := Buffer(structSize, 0)
        NumPut("UInt", structSize, hc, 0)
        if !DllCall("SystemParametersInfo", "UInt", SPI_GETHIGHCONTRAST, "UInt", structSize, "Ptr", hc.Ptr, "UInt", 0)
            return false
        flags := NumGet(hc, 4, "UInt")
        return (flags & HCF_HIGHCONTRASTON) != 0
    } catch {
        return false
    }
}

Beacon_ColorRefToRgb(colorRef) {
    return ((colorRef & 0xFF) << 16) | (colorRef & 0xFF00) | ((colorRef >> 16) & 0xFF)
}

Beacon_GetSystemColor(colorIndex, fallback) {
    try {
        return Beacon_ColorRefToRgb(DllCall("user32\GetSysColor", "Int", colorIndex, "UInt"))
    } catch {
        return fallback
    }
}

Beacon_GetWindowsThemeState() {
    if (Beacon_IsWindowsHighContrastMode())
        return "highcontrast"
    return Beacon_IsWindowsDarkMode() ? "dark" : "light"
}

; Function to get theme colors based on current Windows theme
Beacon_GetThemeColors() {
    themeState := Beacon_GetWindowsThemeState()
    
    if (themeState = "highcontrast") {
        ; High contrast colors come directly from the active Windows contrast theme
        return Map(
            "background", Beacon_GetSystemColor(5, 0x000000),          ; COLOR_WINDOW
            "textColor", Beacon_GetSystemColor(8, 0xFFFFFF),           ; COLOR_WINDOWTEXT
            "editBackground", Beacon_GetSystemColor(5, 0x000000),      ; COLOR_WINDOW
            "editText", Beacon_GetSystemColor(8, 0xFFFFFF),            ; COLOR_WINDOWTEXT
            "buttonBackground", Beacon_GetSystemColor(15, 0x000000),   ; COLOR_BTNFACE
            "buttonText", Beacon_GetSystemColor(18, 0xFFFFFF),         ; COLOR_BTNTEXT
            "menuBackground", Beacon_GetSystemColor(4, 0x000000),      ; COLOR_MENU
            "menuText", Beacon_GetSystemColor(7, 0xFFFFFF),            ; COLOR_MENUTEXT
            "menuHighlight", Beacon_GetSystemColor(13, 0xFFFF00),      ; COLOR_HIGHLIGHT
            "highlightText", Beacon_GetSystemColor(14, 0x000000)       ; COLOR_HIGHLIGHTTEXT
        )
    } else if (themeState = "dark") {
        ; Dark mode colors for dialogs
        return Map(
            "background", 0x202020,        ; Darker background
            "textColor", 0xF0F0F0,         ; Slightly off-white text
            "editBackground", 0x2D2D2D,    ; Darker edit areas
            "editText", 0xFFFFFF,          ; Pure white edit text
            "buttonBackground", 0x404040,   ; Lighter buttons
            "buttonText", 0xFFFFFF,        ; White button text
            "menuBackground", 0x2B2B2B,    ; Menu background
            "menuText", 0xFFFFFF,          ; Menu text
            "menuHighlight", 0x0078D4      ; Menu highlight (Windows blue)
        )
    } else {
        ; Light mode colors for dialogs
        return Map(
            "background", 0xF0F0F0,        ; Light gray background
            "textColor", 0x000000,         ; Black text
            "editBackground", 0xFFFFFF,    ; White background for text areas
            "editText", 0x000000,          ; Black text in edit controls
            "buttonBackground", 0xE1E1E1,   ; Button background
            "buttonText", 0x000000,        ; Button text
            "menuBackground", 0xFFFFFF,    ; Menu background
            "menuText", 0x000000,          ; Menu text
            "menuHighlight", 0x0078D4      ; Menu highlight
        )
    }
}

; Enhanced dark mode support for Windows 10 1903+ and Windows 11
;
; SetPreferredAppMode and FlushMenuThemes are undocumented uxtheme.dll exports
; that must be called by ordinal (not by name):
;   ordinal 135 = SetPreferredAppMode(mode)
;                   0 = Default, 1 = AllowDark, 2 = ForceDark, 3 = ForceLight
;   ordinal 136 = FlushMenuThemes()
;
; Calling them by ordinal makes native popup menus follow the system dark/light
; setting correctly on Windows 10 1903+ and Windows 11.
Beacon_EnableDarkModeForApp() {
    try {
        if (VerCompare(A_OSVersion, "10.0.18362") < 0)
            return  ; Below Windows 10 1903 — dark mode APIs not available

        themeState := Beacon_GetWindowsThemeState()
        isDark := (themeState = "dark")

        ; AllowDark (1) only works when the owner window has also been opted in
        ; via AllowDarkModeForWindow — a per-window call we can't make on AHK's
        ; internal TrackPopupMenuEx owner.  ForceDark (2) / ForceLight (3) bypass
        ; the per-window check entirely and set the rendering mode process-wide,
        ; which is the only reliable way to theme AHK native popup menus.
        ; High contrast must stay in Windows' default renderer so system contrast
        ; colors are not overridden by a forced dark/light app mode.
        preferredMode := (themeState = "highcontrast") ? 0 : (isDark ? 2 : 3)
        try {
            DllCall("uxtheme\#135", "Int", preferredMode)  ; SetPreferredAppMode
            DllCall("uxtheme\#136")                        ; FlushMenuThemes
        } catch {
            ; Ordinal may not exist on very old builds — ignore
        }

        ; Also explicitly opt in the script's main window (ordinal 133 =
        ; AllowDarkModeForWindow).  This covers the owner-window dark mode
        ; check that some Windows builds perform during TrackPopupMenuEx.
        darkFlag := isDark ? 1 : 0
        try {
            DllCall("uxtheme\#133", "Ptr", A_ScriptHwnd, "Int", darkFlag)
        } catch {
            ; Ignore — ordinal may not be present on all builds
        }

        ; Apply immersive dark frame to the script's hidden main window
        try {
            DllCall("dwmapi\DwmSetWindowAttribute",
                "Ptr",  A_ScriptHwnd,
                "UInt", 20,          ; DWMWA_USE_IMMERSIVE_DARK_MODE
                "Int*", darkFlag,
                "UInt", 4)
        } catch {
            ; Ignore if DWM attribute not supported
        }

        ; On Windows 11 the titlebar also needs the attribute set to index 19
        ; for builds before 22000's attribute-20 support.
        if (VerCompare(A_OSVersion, "10.0.22000") >= 0) {
            try {
                DllCall("dwmapi\DwmSetWindowAttribute",
                    "Ptr",  A_ScriptHwnd,
                    "UInt", 19,
                    "Int*", darkFlag,
                    "UInt", 4)
            } catch {
            }
        }
    } catch {
        ; Ignore errors on older Windows versions
    }
}

; Function to refresh theme when system theme changes
Beacon_RefreshApplicationTheme() {
    global BeaconMenu, MenuStructure
    Beacon_EnableDarkModeForApp()

    ; Flush uxtheme's menu theme cache so the next render uses the new theme
    try {
        DllCall("uxtheme\#136")             ; FlushMenuThemes (ordinal 136)
        PostMessage(0x001A, 0, 0, A_ScriptHwnd) ; WM_WININICHANGE
    } catch {
        ; Ignore if calls fail
    }

    ; Rebuild the Menu() object tree so the new HMENU handles are created
    ; under the updated uxtheme context.  AHK caches the old handles otherwise
    ; and the menu continues to render with the previous theme.
    BeaconMenu := BuildMenuFromStructure(MenuStructure)
}

; =============================================================================
;                           GLOBAL DATA STRUCTURES
; =============================================================================

Global ShortcutGuides := Map() ; Will store metadata for each shortcut type

InitializeShortcutGuides() {
    ; This function populates the ShortcutGuides map.
    ; To add a new shortcut section:
    ; 1. Create its Get<n>Content() function.
    ; 2. Add an entry here with its "shortcutType", "title", "description", and "contentCallback".
    ; 3. Add it to the MenuStructure below.

    ShortcutGuides["IntroductionSection"] := Map(
        "title", "Beacon Tutorial and Keyboard Shortcuts System",
        "description", "An overview of Beacon and how to use it:",
        "contentCallback", GetIntroductionContent
    )
    ShortcutGuides["ModifierKeys"] := Map(
        "title", "Keyboard Modifier Keys Reference",
        "description", "Reference guide for keyboard modifier and special keys:",
        "contentCallback", GetModifierKeysContent
    )
    ShortcutGuides["WindowShortcut"] := Map(
        "title", "Windows Keyboard Shortcuts",
        "description", "Windows navigation commands always available to you:",
        "contentCallback", GetWindowShortcutContent
    )
    ShortcutGuides["CtrlShortcut"] := Map(
        "title", "CTRL Keyboard Shortcuts",
        "description", "Common CTRL keyboard shortcuts in Windows:",
        "contentCallback", GetCtrlShortcutContent
    )
    ShortcutGuides["ClipboardShortcut"] := Map(
        "title", "Clipboard Keyboard Shortcuts",
        "description", "Shortcuts for managing the clipboard and clipboard history:",
        "contentCallback", GetClipboardShortcutContent
    )
    ShortcutGuides["TextNavigationShortcut"] := Map(
        "title", "Text Navigation Keyboard Shortcuts",
        "description", "Shortcuts for moving the cursor and selecting text using arrow, F6, and Control keys:",
        "contentCallback", GetTextNavigationShortcutContent
    )
    ShortcutGuides["AppSwitchingShortcut"] := Map(
        "title", "Application Switching Keyboard Shortcuts",
        "description", "Shortcuts for navigating between open applications and windows:",
        "contentCallback", GetAppSwitchingShortcutContent
    )
    ShortcutGuides["ExcelShortcut"] := Map(
        "title", "Microsoft Excel Keyboard Shortcuts",
        "description", "Microsoft Excel keyboard shortcuts to improve productivity:",
        "contentCallback", GetExcelShortcutContent
    )
    ShortcutGuides["WordShortcut"] := Map(
        "title", "Microsoft Word Keyboard Shortcuts",
        "description", "Microsoft Word keyboard shortcuts to improve productivity:",
        "contentCallback", GetWordShortcutContent
    )
    ShortcutGuides["PowerPointShortcut"] := Map(
        "title", "Microsoft PowerPoint Keyboard Shortcuts",
        "description", "Microsoft PowerPoint keyboard shortcuts to improve productivity:",
        "contentCallback", GetPowerPointShortcutContent
    )
    ShortcutGuides["OutlookShortcut"] := Map(
        "title", "Microsoft Outlook Keyboard Shortcuts",
        "description", "Microsoft Outlook keyboard shortcuts to improve productivity:",
        "contentCallback", GetOutlookShortcutContent
    )
    
    ; *** OFFICE 365 ONLINE ENTRIES ***
    ShortcutGuides["WordOnlineShortcut"] := Map(
        "title", "Microsoft Word Online Keyboard Shortcuts",
        "description", "Microsoft Word Online (Office 365) keyboard shortcuts for web-based document editing:",
        "contentCallback", GetWordOnlineShortcutContent
    )
    ShortcutGuides["ExcelOnlineShortcut"] := Map(
        "title", "Microsoft Excel Online Keyboard Shortcuts", 
        "description", "Microsoft Excel Online (Office 365) keyboard shortcuts for web-based spreadsheet management:",
        "contentCallback", GetExcelOnlineShortcutContent
    )
    ShortcutGuides["PowerPointOnlineShortcut"] := Map(
        "title", "Microsoft PowerPoint Online Keyboard Shortcuts",
        "description", "Microsoft PowerPoint Online (Office 365) keyboard shortcuts for web-based presentations:",
        "contentCallback", GetPowerPointOnlineShortcutContent
    )
    ShortcutGuides["OutlookOnlineShortcut"] := Map(
        "title", "Microsoft Outlook Online Keyboard Shortcuts",
        "description", "Microsoft Outlook Online (Outlook on the web) keyboard shortcuts for web-based email:",
        "contentCallback", GetOutlookOnlineShortcutContent
    )
    ShortcutGuides["OneNoteOnlineShortcut"] := Map(
        "title", "Microsoft OneNote Online Keyboard Shortcuts",
        "description", "Microsoft OneNote Online (Office 365) keyboard shortcuts for web-based note-taking:",
        "contentCallback", GetOneNoteOnlineShortcutContent
    )
    ShortcutGuides["TeamsWebShortcut"] := Map(
        "title", "Microsoft Teams Web Keyboard Shortcuts",
        "description", "Microsoft Teams web application keyboard shortcuts for online collaboration:",
        "contentCallback", GetTeamsWebShortcutContent
    )
    ShortcutGuides["OneDriveWebShortcut"] := Map(
        "title", "Microsoft OneDrive Web Keyboard Shortcuts",
        "description", "Microsoft OneDrive web interface keyboard shortcuts for cloud file management:",
        "contentCallback", GetOneDriveWebShortcutContent
    )
    ShortcutGuides["SharePointOnlineShortcut"] := Map(
        "title", "Microsoft SharePoint Online Keyboard Shortcuts",
        "description", "Microsoft SharePoint Online keyboard shortcuts for web-based collaboration and document management:",
        "contentCallback", GetSharePointOnlineShortcutContent
    )
    
    ; *** DEFAULT WINDOWS APPLICATIONS ENTRIES ***
    ShortcutGuides["CalculatorShortcut"] := Map(
        "title", "Windows Calculator Keyboard Shortcuts",
        "description", "Windows Calculator keyboard shortcuts for mathematical operations:",
        "contentCallback", GetCalculatorShortcutContent
    )
    ShortcutGuides["NotepadShortcut"] := Map(
        "title", "Windows Notepad Keyboard Shortcuts",
        "description", "Windows Notepad keyboard shortcuts for basic text editing:",
        "contentCallback", GetNotepadShortcutContent
    )
    ShortcutGuides["WordPadShortcut"] := Map(
        "title", "Windows WordPad Keyboard Shortcuts",
        "description", "Windows WordPad keyboard shortcuts for rich text editing:",
        "contentCallback", GetWordPadShortcutContent
    )
    ShortcutGuides["PaintShortcut"] := Map(
        "title", "Windows Paint Keyboard Shortcuts",
        "description", "Windows Paint keyboard shortcuts for basic image editing:",
        "contentCallback", GetPaintShortcutContent
    )
    ShortcutGuides["SnippingToolShortcut"] := Map(
        "title", "Snipping Tool & Snip & Sketch Shortcuts",
        "description", "Windows screenshot tools keyboard shortcuts:",
        "contentCallback", GetSnippingToolShortcutContent
    )
    ShortcutGuides["PhotosShortcut"] := Map(
        "title", "Windows Photos App Keyboard Shortcuts",
        "description", "Windows Photos app keyboard shortcuts for viewing and editing images:",
        "contentCallback", GetPhotosShortcutContent
    )
    ShortcutGuides["WindowsMailShortcut"] := Map(
        "title", "Windows Mail App Keyboard Shortcuts",
        "description", "Windows Mail app keyboard shortcuts for email management:",
        "contentCallback", GetWindowsMailShortcutContent
    )
    ShortcutGuides["WindowsCalendarShortcut"] := Map(
        "title", "Windows Calendar App Keyboard Shortcuts",
        "description", "Windows Calendar app keyboard shortcuts for schedule management:",
        "contentCallback", GetWindowsCalendarShortcutContent
    )
    ShortcutGuides["WindowsMapsShortcut"] := Map(
        "title", "Windows Maps App Keyboard Shortcuts",
        "description", "Windows Maps app keyboard shortcuts for navigation:",
        "contentCallback", GetWindowsMapsShortcutContent
    )
    ShortcutGuides["WindowsSettingsShortcut"] := Map(
        "title", "Windows Settings App Keyboard Shortcuts",
        "description", "Windows Settings app keyboard shortcuts for system configuration:",
        "contentCallback", GetWindowsSettingsShortcutContent
    )
    ShortcutGuides["TaskManagerShortcut"] := Map(
        "title", "Windows Task Manager Keyboard Shortcuts",
        "description", "Windows Task Manager keyboard shortcuts for system monitoring:",
        "contentCallback", GetTaskManagerShortcutContent
    )
    ShortcutGuides["CommandPromptShortcut"] := Map(
        "title", "Command Prompt Keyboard Shortcuts",
        "description", "Windows Command Prompt keyboard shortcuts for command line operations:",
        "contentCallback", GetCommandPromptShortcutContent
    )
    ShortcutGuides["PowerShellShortcut"] := Map(
        "title", "Windows PowerShell Keyboard Shortcuts",
        "description", "Windows PowerShell keyboard shortcuts for advanced command line operations:",
        "contentCallback", GetPowerShellShortcutContent
    )
    ShortcutGuides["WindowsTerminalShortcut"] := Map(
        "title", "Windows Terminal Keyboard Shortcuts",
        "description", "Windows Terminal keyboard shortcuts for modern command line interface:",
        "contentCallback", GetWindowsTerminalShortcutContent
    )
    ShortcutGuides["StickyNotesShortcut"] := Map(
        "title", "Windows Sticky Notes Keyboard Shortcuts",
        "description", "Windows Sticky Notes keyboard shortcuts for quick note-taking:",
        "contentCallback", GetStickyNotesShortcutContent
    )
    ShortcutGuides["VoiceRecorderShortcut"] := Map(
        "title", "Windows Voice Recorder Keyboard Shortcuts",
        "description", "Windows Voice Recorder keyboard shortcuts for audio recording:",
        "contentCallback", GetVoiceRecorderShortcutContent
    )
    
    ShortcutGuides["GoogleDocsShortcut"] := Map(
        "title", "Google Docs Keyboard Shortcuts",
        "description", "Google Docs keyboard shortcuts for document editing and formatting:",
        "contentCallback", GetGoogleDocsShortcutContent
    )
    ShortcutGuides["GoogleSheetsShortcut"] := Map(
        "title", "Google Sheets Keyboard Shortcuts",
        "description", "Google Sheets keyboard shortcuts for spreadsheet management:",
        "contentCallback", GetGoogleSheetsShortcutContent
    )
    ShortcutGuides["GoogleSlidesShortcut"] := Map(
        "title", "Google Slides Keyboard Shortcuts",
        "description", "Google Slides keyboard shortcuts for presentation creation:",
        "contentCallback", GetGoogleSlidesShortcutContent
    )
    ShortcutGuides["GmailShortcut"] := Map(
        "title", "Gmail Keyboard Shortcuts",
        "description", "Gmail keyboard shortcuts for email management and navigation:",
        "contentCallback", GetGmailShortcutContent
    )
    ShortcutGuides["GoogleMeetShortcut"] := Map(
        "title", "Google Meet Keyboard Shortcuts",
        "description", "Keyboard shortcuts for Google Meet video conferencing:",
        "contentCallback", GetGoogleMeetShortcutContent
    )
    ShortcutGuides["GoogleDriveShortcut"] := Map(
        "title", "Google Drive Keyboard Shortcuts",
        "description", "Google Drive web keyboard shortcuts for navigation, selection, file actions, and creation:",
        "contentCallback", GetGoogleDriveShortcutContent
    )
    ShortcutGuides["GoogleCalendarShortcut"] := Map(
        "title", "Google Calendar Keyboard Shortcuts",
        "description", "Google Calendar web keyboard shortcuts for calendar navigation, views, events, and tasks:",
        "contentCallback", GetGoogleCalendarShortcutContent
    )
    ShortcutGuides["GoogleChatShortcut"] := Map(
        "title", "Google Chat Keyboard Shortcuts",
        "description", "Google Chat web keyboard shortcuts for chats, spaces, threads, and messages:",
        "contentCallback", GetGoogleChatShortcutContent
    )
    ShortcutGuides["BrowserShortcut"] := Map(
        "title", "Web Browser Keyboard Shortcuts",
        "description", "Common web browser keyboard shortcuts:",
        "contentCallback", GetBrowserShortcutContent
    )
    ShortcutGuides["FileExplorerShortcut"] := Map(
        "title", "Windows File Explorer Keyboard Shortcuts",
        "description", "Windows File Explorer keyboard shortcuts to improve productivity:",
        "contentCallback", GetFileExplorerShortcutContent
    )
    ShortcutGuides["YouTubeShortcut"] := Map(
        "title", "YouTube Keyboard Shortcuts",
        "description", "Keyboard shortcuts for navigating and controlling YouTube playback:",
        "contentCallback", GetYouTubeShortcutContent
    )
    ShortcutGuides["YouTubeMusicShortcut"] := Map(
        "title", "YouTube Music Keyboard Shortcuts",
        "description", "Keyboard shortcuts for YouTube Music playback and navigation:",
        "contentCallback", GetYouTubeMusicShortcutContent
    )
    ShortcutGuides["FacebookShortcut"] := Map(
        "title", "Facebook Keyboard Shortcuts",
        "description", "Facebook web keyboard shortcuts for Feed navigation, post actions, search, and access keys:",
        "contentCallback", GetFacebookShortcutContent
    )
    ShortcutGuides["XShortcut"] := Map(
        "title", "X / Twitter Keyboard Shortcuts",
        "description", "X.com keyboard shortcuts for posts, navigation, timelines, and direct messages:",
        "contentCallback", GetXShortcutContent
    )
    ShortcutGuides["LinkedInShortcut"] := Map(
        "title", "LinkedIn Keyboard Shortcuts",
        "description", "LinkedIn desktop web keyboard shortcuts for Feed, navigation, and notifications:",
        "contentCallback", GetLinkedInShortcutContent
    )
    ShortcutGuides["GitHubWebShortcut"] := Map(
        "title", "GitHub Website Keyboard Shortcuts",
        "description", "GitHub.com keyboard shortcuts for repositories, code, issues, pull requests, and notifications:",
        "contentCallback", GetGitHubWebShortcutContent
    )
    ShortcutGuides["NotionShortcut"] := Map(
        "title", "Notion Keyboard Shortcuts",
        "description", "Notion web and desktop keyboard shortcuts for navigation, editing, blocks, Markdown, and slash commands:",
        "contentCallback", GetNotionShortcutContent
    )
    ShortcutGuides["DropboxShortcut"] := Map(
        "title", "Dropbox Website Keyboard Shortcuts",
        "description", "Dropbox.com keyboard shortcuts for Files navigation, opening, search, and selection:",
        "contentCallback", GetDropboxShortcutContent
    )
    ShortcutGuides["FigmaShortcut"] := Map(
        "title", "Figma Keyboard Shortcuts",
        "description", "Figma web and desktop keyboard shortcuts for canvas navigation, selection, layers, view controls, and accessibility:",
        "contentCallback", GetFigmaShortcutContent
    )
    ShortcutGuides["TrelloShortcut"] := Map(
        "title", "Trello Keyboard Shortcuts",
        "description", "Trello keyboard shortcuts for boards, cards, filters, navigation, and common actions:",
        "contentCallback", GetTrelloShortcutContent
    )
    ShortcutGuides["CanvaShortcut"] := Map(
        "title", "Canva Keyboard Shortcuts",
        "description", "Canva editor keyboard shortcuts for moving elements, text, selection, grouping, search, and presentation:",
        "contentCallback", GetCanvaShortcutContent
    )
    ShortcutGuides["MondayShortcut"] := Map(
        "title", "monday.com Keyboard Shortcuts",
        "description", "monday.com shortcuts for system navigation, board navigation, table editing, and WorkCanvas:",
        "contentCallback", GetMondayShortcutContent
    )
    ShortcutGuides["VLCShortcut"] := Map(
        "title", "VLC Media Player Keyboard Shortcuts",
        "description", "Common keyboard shortcuts for VLC Media Player:",
        "contentCallback", GetVLCShortcutContent
    )
    ShortcutGuides["ReaperShortcut"] := Map(
        "title", "Reaper Keyboard Shortcuts",
        "description", "Keyboard shortcuts for the Reaper Digital Audio Workstation:",
        "contentCallback", GetReaperShortcutContent
    )
    ShortcutGuides["WindowsMediaPlayerShortcut"] := Map(
        "title", "Windows Media Player Keyboard Shortcuts",
        "description", "Common keyboard shortcuts for Windows Media Player:",
        "contentCallback", GetWindowsMediaPlayerShortcutContent
    )
    ShortcutGuides["AudacityShortcut"] := Map(
        "title", "Audacity Keyboard Shortcuts",
        "description", "Common keyboard shortcuts for the Audacity audio editor:",
        "contentCallback", GetAudacityShortcutContent
    )
    ShortcutGuides["AccessibilityShortcut"] := Map(
        "title", "Windows Accessibility Shortcuts",
        "description", "Windows accessibility features and keyboard shortcuts:",
        "contentCallback", GetAccessibilityShortcutContent
    )
    ShortcutGuides["MagnifierShortcut"] := Map(
        "title", "Windows Magnifier Keyboard Shortcuts",
        "description", "Windows Magnifier keyboard shortcuts:",
        "contentCallback", GetMagnifierShortcutContent
    )
    ShortcutGuides["NarratorShortcut"] := Map(
        "title", "Windows Narrator Keyboard Shortcuts",
        "description", "Windows Narrator screen reader keyboard shortcuts:",
        "contentCallback", GetNarratorShortcutContent
    )
    ShortcutGuides["JAWSShortcut"] := Map(
        "title", "JAWS Screen Reader Keyboard Shortcuts",
        "description", "JAWS (Job Access With Speech) keyboard shortcuts for screen reader navigation:",
        "contentCallback", GetJAWSShortcutContent
    )
    ShortcutGuides["NVDAShortcut"] := Map(
        "title", "NVDA Screen Reader Keyboard Shortcuts",
        "description", "NVDA (NonVisual Desktop Access) keyboard shortcuts for screen reader navigation:",
        "contentCallback", GetNVDAShortcutContent
    )
    ShortcutGuides["AdobeReaderShortcut"] := Map(
        "title", "Adobe Reader Keyboard Shortcuts",
        "description", "Adobe Reader keyboard shortcuts to improve PDF viewing productivity:",
        "contentCallback", GetAdobeReaderShortcutContent
    )
    ShortcutGuides["ZoomShortcut"] := Map(
        "title", "Zoom Video Conference Keyboard Shortcuts",
        "description", "Zoom video conferencing keyboard shortcuts to improve your virtual meetings:",
        "contentCallback", GetZoomShortcutContent
    )
    ShortcutGuides["TeamsShortcut"] := Map(
        "title", "Microsoft Teams Keyboard Shortcuts",
        "description", "Microsoft Teams keyboard shortcuts to enhance collaboration:",
        "contentCallback", GetTeamsShortcutContent
    )
    ShortcutGuides["AccessibilityNotes"] := Map(
        "title", "Accessibility Notes and Resources",
        "description", "Additional accessibility information and resources:",
        "contentCallback", GetAccessibilityNotesContent
    )
    ShortcutGuides["ZoomTextShortcut"] := Map(
        "title", "ZoomText Keyboard Shortcuts",
        "description", "Common keyboard shortcuts for ZoomText Magnifier/Reader:",
        "contentCallback", GetZoomTextShortcutContent
    )
    ShortcutGuides["VoiceAccessShortcut"] := Map(
        "title", "Windows Voice Access Shortcuts",
        "description", "Commands and information for Windows Voice Access:",
        "contentCallback", GetVoiceAccessShortcutContent
    )
    ShortcutGuides["MicrosoftDictateShortcut"] := Map(
        "title", "Microsoft Dictate (Voice Typing) Shortcuts",
        "description", "Keyboard shortcuts for Microsoft Dictate (Windows Voice Typing):",
        "contentCallback", GetMicrosoftDictateContent
    )
    ShortcutGuides["DragonShortcut"] := Map(
        "title", "Dragon NaturallySpeaking / Dragon Professional Shortcuts",
        "description", "Voice commands and keyboard shortcuts for Dragon speech recognition:",
        "contentCallback", GetDragonShortcutContent
    )
    ShortcutGuides["Kurzweil1000Shortcut"] := Map(
        "title", "Kurzweil 1000 Keyboard Shortcuts",
        "description", "Keyboard shortcuts for Kurzweil 1000 reading software:",
        "contentCallback", GetKurzweil1000ShortcutContent
    )
    ShortcutGuides["Kurzweil3000Shortcut"] := Map(
        "title", "Kurzweil 3000 Keyboard Shortcuts",
        "description", "Keyboard shortcuts for Kurzweil 3000 reading and writing software:",
        "contentCallback", GetKurzweil3000ShortcutContent
    )
    ShortcutGuides["IPEVOVisualizerShortcut"] := Map(
        "title", "IPEVO Visualizer Keyboard Shortcuts",
        "description", "Keyboard shortcuts for IPEVO Visualizer document camera software:",
        "contentCallback", GetIPEVOVisualizerShortcutContent
    )
    ShortcutGuides["ContactUsSection"] := Map(
        "title", "Contact Us",
        "description", "How to get in touch or find more information:",
        "contentCallback", GetContactUsContent,
        "actionButton", Map("label", "Visit Website", "url", "https://www.eyetechanalytics.com")
    )
    ShortcutGuides["VSCodeShortcut"] := Map(
        "title", "Visual Studio Code Keyboard Shortcuts",
        "description", "VS Code keyboard shortcuts for editing, navigation, debugging, and the terminal:",
        "contentCallback", GetVSCodeShortcutContent
    )
    ShortcutGuides["NotepadPlusPlusShortcut"] := Map(
        "title", "Notepad++ Keyboard Shortcuts",
        "description", "Notepad++ keyboard shortcuts for editing, search, macros, and code folding:",
        "contentCallback", GetNotepadPlusPlusShortcutContent
    )
    ShortcutGuides["SpotifyShortcut"] := Map(
        "title", "Spotify Keyboard Shortcuts",
        "description", "Spotify keyboard shortcuts for playback, navigation, and library management:",
        "contentCallback", GetSpotifyShortcutContent
    )
    ShortcutGuides["SlackShortcut"] := Map(
        "title", "Slack Keyboard Shortcuts",
        "description", "Slack keyboard shortcuts for navigation, messaging, formatting, and calls:",
        "contentCallback", GetSlackShortcutContent
    )
    ShortcutGuides["DiscordShortcut"] := Map(
        "title", "Discord Keyboard Shortcuts",
        "description", "Discord keyboard shortcuts for navigation, messaging, voice, and video:",
        "contentCallback", GetDiscordShortcutContent
    )
    ShortcutGuides["OBSShortcut"] := Map(
        "title", "OBS Studio Keyboard Shortcuts",
        "description", "OBS Studio shortcuts for streaming, recording, scenes, sources, and layout:",
        "contentCallback", GetOBSShortcutContent
    )
    ShortcutGuides["DaVinciResolveShortcut"] := Map(
        "title", "DaVinci Resolve Keyboard Shortcuts",
        "description", "DaVinci Resolve shortcuts for playback, editing, color, and page navigation:",
        "contentCallback", GetDaVinciResolveShortcutContent
    )
    ShortcutGuides["PremierProShortcut"] := Map(
        "title", "Adobe Premiere Pro Keyboard Shortcuts",
        "description", "Adobe Premiere Pro shortcuts for playback, editing, tools, and workspaces:",
        "contentCallback", GetPremierProShortcutContent
    )
    ShortcutGuides["SevenZipShortcut"] := Map(
        "title", "7-Zip Keyboard Shortcuts",
        "description", "7-Zip keyboard shortcuts for navigation, file operations, and selection:",
        "contentCallback", GetSevenZipShortcutContent
    )
    ShortcutGuides["WinRARShortcut"] := Map(
        "title", "WinRAR Keyboard Shortcuts",
        "description", "WinRAR keyboard shortcuts for archive management, extraction, and file operations:",
        "contentCallback", GetWinRARShortcutContent
    )
    ShortcutGuides["AccessShortcut"] := Map(
        "title", "Microsoft Access Keyboard Shortcuts",
        "description", "Microsoft Access keyboard shortcuts for records, navigation, and query design:",
        "contentCallback", GetAccessShortcutContent
    )
    ShortcutGuides["PhotoshopShortcut"] := Map(
        "title", "Adobe Photoshop Keyboard Shortcuts",
        "description", "Adobe Photoshop shortcuts for tools, layers, selections, and image adjustments:",
        "contentCallback", GetPhotoshopShortcutContent
    )
    ShortcutGuides["Foobar2000Shortcut"] := Map(
        "title", "foobar2000 Keyboard Shortcuts",
        "description", "foobar2000 keyboard shortcuts for playback, playlist management, and navigation:",
        "contentCallback", GetFoobar2000ShortcutContent
    )
    ShortcutGuides["ITunesShortcut"] := Map(
        "title", "iTunes / Apple Music Keyboard Shortcuts",
        "description", "iTunes keyboard shortcuts for playback, navigation, and library management:",
        "contentCallback", GetITunesShortcutContent
    )
    ShortcutGuides["LibreWriterShortcut"] := Map(
        "title", "LibreOffice Writer Keyboard Shortcuts",
        "description", "LibreOffice Writer shortcuts for editing, styles, navigation, and track changes:",
        "contentCallback", GetLibreOfficeWriterShortcutContent
    )
    ShortcutGuides["LibreCalcShortcut"] := Map(
        "title", "LibreOffice Calc Keyboard Shortcuts",
        "description", "LibreOffice Calc shortcuts for navigation, formulas, formatting, and AutoFilter:",
        "contentCallback", GetLibreOfficeCalcShortcutContent
    )
    ShortcutGuides["LibreImpressShortcut"] := Map(
        "title", "LibreOffice Impress Keyboard Shortcuts",
        "description", "LibreOffice Impress shortcuts for slides, text editing, and slide show controls:",
        "contentCallback", GetLibreOfficeImpressShortcutContent
    )
    ShortcutGuides["ReadAndWriteShortcut"] := Map(
        "title", "Read&Write by Texthelp Shortcuts",
        "description", "Keyboard shortcuts for the Read&Write literacy support toolbar:",
        "contentCallback", GetReadAndWriteShortcutContent
    )
    ShortcutGuides["MAGicShortcut"] := Map(
        "title", "MAGic Screen Magnification Shortcuts",
        "description", "Keyboard shortcuts for MAGic by Freedom Scientific (Vispero):",
        "contentCallback", GetMAGicShortcutContent
    )
    ShortcutGuides["SuperNovaShortcut"] := Map(
        "title", "Dolphin SuperNova Shortcuts",
        "description", "Keyboard shortcuts for Dolphin SuperNova screen reader and magnifier:",
        "contentCallback", GetSuperNovaShortcutContent
    )
    ShortcutGuides["OSKShortcut"] := Map(
        "title", "Windows On-Screen Keyboard",
        "description", "How to open and use the Windows On-Screen Keyboard (osk.exe):",
        "contentCallback", GetOSKShortcutContent
    )
    ShortcutGuides["WindowsSpeechRecognitionShortcut"] := Map(
        "title", "Windows Speech Recognition (Classic)",
        "description", "Voice commands and shortcuts for Windows Speech Recognition (WSR):",
        "contentCallback", GetWindowsSpeechRecognitionShortcutContent
    )
    ShortcutGuides["NaturalReaderShortcut"] := Map(
        "title", "NaturalReader Shortcuts",
        "description", "Keyboard shortcuts for NaturalReader text-to-speech software:",
        "contentCallback", GetNaturalReaderShortcutContent
    )
    ShortcutGuides["EaseOfAccessShortcut"] := Map(
        "title", "Windows Ease of Access Features",
        "description", "Keyboard shortcuts for Sticky Keys, Filter Keys, Mouse Keys, and other Ease of Access tools:",
        "contentCallback", GetEaseOfAccessShortcutContent
    )
    ; --- ADD NEW SHORTCUT GUIDE METADATA ABOVE THIS LINE ---
}

Global MenuStructure := [
    ["Introduction", "IntroductionSection"],
    [""], ; Separator after Introduction
    ["Modifier Keys Reference", "ModifierKeys"],
    ["Windows Shortcut commands", "WindowShortcut"],
    ["Control Shortcut commands", "CtrlShortcut"],
    ["Clipboard Shortcuts", "ClipboardShortcut"],
    ["Application Switching", "AppSwitchingShortcut"],
    [""], ; Separator
    ["Microsoft Office (Desktop)", [ ; Submenu
        ["Excel Shortcuts", "ExcelShortcut"],
        ["Word Shortcuts", "WordShortcut"],
        ["PowerPoint Shortcuts", "PowerPointShortcut"],
        ["Outlook Shortcuts", "OutlookShortcut"],
        ["Access Shortcuts", "AccessShortcut"]
    ]],
    ["Office 365 Online", [ ; Submenu
        ["Word Online Shortcuts", "WordOnlineShortcut"],
        ["Excel Online Shortcuts", "ExcelOnlineShortcut"],
        ["PowerPoint Online Shortcuts", "PowerPointOnlineShortcut"],
        ["Outlook Online Shortcuts", "OutlookOnlineShortcut"],
        ["OneNote Online Shortcuts", "OneNoteOnlineShortcut"],
        ["Teams Web Shortcuts", "TeamsWebShortcut"],
        ["OneDrive Web Shortcuts", "OneDriveWebShortcut"],
        ["SharePoint Online Shortcuts", "SharePointOnlineShortcut"]
    ]],
    ["LibreOffice", [ ; Submenu
        ["Writer Shortcuts", "LibreWriterShortcut"],
        ["Calc Shortcuts", "LibreCalcShortcut"],
        ["Impress Shortcuts", "LibreImpressShortcut"]
    ]],
    ["Google Suite", [ ; Submenu
        ["Google Docs Shortcuts", "GoogleDocsShortcut"],
        ["Google Sheets Shortcuts", "GoogleSheetsShortcut"],
        ["Google Slides Shortcuts", "GoogleSlidesShortcut"],
        ["Gmail Shortcuts", "GmailShortcut"],
        ["Google Meet Shortcuts", "GoogleMeetShortcut"],
        ["Google Drive Shortcuts", "GoogleDriveShortcut"],
        ["Google Calendar Shortcuts", "GoogleCalendarShortcut"],
        ["Google Chat Shortcuts", "GoogleChatShortcut"]
    ]],
    [""], ; Separator
    ["Windows Built-in Apps", [ ; Submenu for Windows Apps
        ["Calculator Shortcuts", "CalculatorShortcut"],
        ["Notepad Shortcuts", "NotepadShortcut"],
        ["WordPad Shortcuts", "WordPadShortcut"],
        ["Paint Shortcuts", "PaintShortcut"],
        ["Snipping Tool Shortcuts", "SnippingToolShortcut"],
        ["Photos App Shortcuts", "PhotosShortcut"],
        ["Windows Mail Shortcuts", "WindowsMailShortcut"],
        ["Windows Calendar Shortcuts", "WindowsCalendarShortcut"],
        ["Windows Maps Shortcuts", "WindowsMapsShortcut"],
        ["Windows Settings Shortcuts", "WindowsSettingsShortcut"],
        ["Sticky Notes Shortcuts", "StickyNotesShortcut"],
        ["Voice Recorder Shortcuts", "VoiceRecorderShortcut"]
    ]],
    ["System Tools", [ ; Submenu for System Tools
        ["Task Manager Shortcuts", "TaskManagerShortcut"],
        ["Command Prompt Shortcuts", "CommandPromptShortcut"],
        ["PowerShell Shortcuts", "PowerShellShortcut"],
        ["Windows Terminal Shortcuts", "WindowsTerminalShortcut"]
    ]],
    [""], ; Separator
    ["Browser Shortcut commands", "BrowserShortcut"],
    ["Websites && Web Apps", [
        ["Facebook Shortcuts", "FacebookShortcut"],
        ["X / Twitter Shortcuts", "XShortcut"],
        ["LinkedIn Shortcuts", "LinkedInShortcut"],
        ["GitHub Website Shortcuts", "GitHubWebShortcut"],
        ["Notion Shortcuts", "NotionShortcut"],
        ["Dropbox Website Shortcuts", "DropboxShortcut"],
        ["Figma Shortcuts", "FigmaShortcut"],
        ["Trello Shortcuts", "TrelloShortcut"],
        ["Canva Shortcuts", "CanvaShortcut"],
        ["monday.com Shortcuts", "MondayShortcut"]
    ]],
    ["File Explorer Shortcuts", "FileExplorerShortcut"],
    ["Adobe Reader Shortcuts", "AdobeReaderShortcut"],
    [""], ; Separator
    ["Code && Text Editors", [ ; Submenu
        ["Visual Studio Code Shortcuts", "VSCodeShortcut"],
        ["Notepad++ Shortcuts", "NotepadPlusPlusShortcut"]
    ]],
    ["Creative Applications", [ ; Submenu
        ["Adobe Photoshop Shortcuts", "PhotoshopShortcut"]
    ]],
    ["File Utilities", [ ; Submenu
        ["7-Zip Shortcuts", "SevenZipShortcut"],
        ["WinRAR Shortcuts", "WinRARShortcut"]
    ]],
    ["Communication && Collaboration", [ ; Submenu
        ["Zoom Shortcuts", "ZoomShortcut"],
        ["Microsoft Teams Shortcuts", "TeamsShortcut"],
        ["Slack Shortcuts", "SlackShortcut"],
        ["Discord Shortcuts", "DiscordShortcut"]
    ]],
    [""], ; Separator
    ["Multimedia Applications", [ ; Submenu
        ["Music Players", [
            ["Spotify Shortcuts", "SpotifyShortcut"],
            ["foobar2000 Shortcuts", "Foobar2000Shortcut"],
            ["iTunes / Apple Music Shortcuts", "ITunesShortcut"],
            ["YouTube Music Shortcuts", "YouTubeMusicShortcut"],
            ["VLC Shortcuts", "VLCShortcut"],
            ["Windows Media Player Shortcuts", "WindowsMediaPlayerShortcut"]
        ]],
        ["Audio Production", [
            ["Reaper Shortcuts", "ReaperShortcut"],
            ["Audacity Shortcuts", "AudacityShortcut"]
        ]],
        ["Video Production", [
            ["DaVinci Resolve Shortcuts", "DaVinciResolveShortcut"],
            ["Adobe Premiere Pro Shortcuts", "PremierProShortcut"]
        ]],
        ["Streaming && Recording", [
            ["OBS Studio Shortcuts", "OBSShortcut"]
        ]],
        ["Online Video", [
            ["YouTube Shortcuts", "YouTubeShortcut"]
        ]]
    ]],
    [""], ; Separator
    ["Accessibility Options", [ ; Submenu
        ["Accessibility Overview", "AccessibilityShortcut"],
        ["Text Navigation (Keyboard)", "TextNavigationShortcut"],
        ["Ease of Access Features", "EaseOfAccessShortcut"],
        ["Screen Readers", [
            ["JAWS Screen Reader", "JAWSShortcut"],
            ["NVDA Screen Reader", "NVDAShortcut"],
            ["Windows Narrator", "NarratorShortcut"]
        ]],
        ["Magnification", [
            ["Windows Magnifier", "MagnifierShortcut"],
            ["ZoomText / Fusion", "ZoomTextShortcut"],
            ["MAGic (Freedom Scientific)", "MAGicShortcut"]
        ]],
        ["Combined Reader + Magnifier", [
            ["Dolphin SuperNova", "SuperNovaShortcut"]
        ]],
        ["Literacy && Reading Support", [
            ["Read&&Write by Texthelp", "ReadAndWriteShortcut"],
            ["NaturalReader", "NaturalReaderShortcut"],
            ["Kurzweil 1000", "Kurzweil1000Shortcut"],
            ["Kurzweil 3000", "Kurzweil3000Shortcut"]
        ]],
        ["Voice && Speech Input", [
            ["Windows Voice Access", "VoiceAccessShortcut"],
            ["Windows Speech Recognition", "WindowsSpeechRecognitionShortcut"],
            ["Microsoft Dictate", "MicrosoftDictateShortcut"],
            ["Dragon NaturallySpeaking", "DragonShortcut"]
        ]],
        ["Input Assistance", [
            ["On-Screen Keyboard", "OSKShortcut"],
            ["IPEVO Visualizer", "IPEVOVisualizerShortcut"]
        ]],
        ["Accessibility Notes", "AccessibilityNotes"]
    ]],
    [""], ; Separator
    ["Settings", "BeaconSettings"],
    ["Contact Us", "ContactUsSection"]
    ; --- ADD NEW TOP-LEVEL MENU ITEMS OR SUBMENUS ABOVE THIS LINE ---
]

; =============================================================================
;                    NATIVE MENU SYSTEM  (JAWS-ACCESSIBLE)
; =============================================================================
;
;   Uses AHK built-in Menu() objects, which create standard Windows popup
;   menus.  Native menus are fully accessible to screen readers (JAWS, NVDA,
;   Narrator, etc.), support arrow-key and keyboard navigation out of the box,
;   and require no custom focus or highlight management.
;
;   The MenuStructure array defined above is walked once at startup by
;   InitBeaconMenu() to build the nested Menu() objects.  After that,
;   ShowKeyboardMenu() simply calls BeaconMenu.Show().

; Root menu object — built once by InitBeaconMenu() at startup.
Global BeaconMenu := ""

; Track the current theme so we can detect changes
Global CurrentTheme := Beacon_GetWindowsThemeState()

; -----------------------------------------------------------------------
; BuildMenuFromStructure(structure)
;   Recursively converts a MenuStructure array into native Menu() objects.
;   Each element is either:
;     ["Label", "ShortcutGuideKey"]   → leaf item
;     ["Label", [...]]                → sub-menu (recurse)
;     [""]                            → separator
; -----------------------------------------------------------------------
; Returns a fresh closure that calls ShowShortcutGuide(key).
; Called once per leaf item so each closure captures its own 'key' value,
; avoiding the shared-variable problem that occurs with closures in loops.
MakeGuideHandler(key) {
    return (*)=> ShowShortcutGuide(key)
}

BuildMenuFromStructure(structure) {
    m := Menu()
    for item in structure {
        if (item.Length = 1 && item[1] = "") {
            ; Separator
            m.Add()
        } else if (item.Length = 2) {
            label  := item[1]
            action := item[2]
            if IsObject(action) {
                ; Sub-menu — recurse and attach
                subM := BuildMenuFromStructure(action)
                m.Add(label, subM)
            } else if (action = "BeaconSettings") {
                ; Special item — opens the Settings dialog
                m.Add(label, (*)=> ShowSettingsDialog())
            } else {
                ; Leaf item — MakeGuideHandler() creates a fresh closure per
                ; item, avoiding the closure-in-loop shared-variable problem
                m.Add(label, MakeGuideHandler(action))
            }
        }
    }
    return m
}

; Build the native menu tree from MenuStructure.
; Called once during INITIALIZATION (see bottom of file).
InitBeaconMenu() {
    global BeaconMenu, MenuStructure
    BeaconMenu := BuildMenuFromStructure(MenuStructure)
}

; Show the shortcuts navigation menu.
; Called by the hotkeys and by ShowContextualShortcuts() as a fallback.
ShowKeyboardMenu() {
    global BeaconMenu
    BeaconMenu.Show()
}

; =============================================================================
;                    THEME MONITORING SYSTEM
; =============================================================================

; Compares current Windows theme to the stored state and refreshes if changed.
; Called on a 2-second timer by Beacon_SetupThemeMonitoring().
Beacon_CheckThemeChange() {
    global CurrentTheme
    newTheme := Beacon_GetWindowsThemeState()
    if (newTheme != CurrentTheme) {
        CurrentTheme := newTheme
        Beacon_RefreshApplicationTheme()
    }
}

; Start a periodic timer to detect system theme changes
Beacon_SetupThemeMonitoring() {
    SetTimer(Beacon_CheckThemeChange, 2000)
}

; Function to handle Windows theme change messages
Beacon_OnThemeChange() {
    global CurrentTheme
    CurrentTheme := Beacon_GetWindowsThemeState()
    ; Refresh application theme when Windows theme changes
    Beacon_RefreshApplicationTheme()
}

; =============================================================================
;                    SETTINGS SYSTEM
; =============================================================================
;
;   Manages persistent preferences stored in Beacon_Settings.ini:
;     1. Windows startup registration (HKCU Run registry key)
;     2. User-configurable hotkeys (registered dynamically via Hotkey())
;     3. Announce Commands feedback
;
;   Built-in hotkeys:
;     Menu hotkey       : Windows+Shift+H  (#+h)
;     Contextual hotkey : Windows+Shift+K  (#+k)
;     Legacy fallback   : Backtick+1 / Backtick+2
; =============================================================================

; Current version — keep this in sync with the file name for compiled releases
; (e.g. Beacon.4.5.exe).  The update checker compares this against the value
; in Beacon_version.txt hosted on the download server.
Global Beacon_Version := "4.5"

; Path to the INI file sitting next to the script
Global Beacon_SettingsFile := A_ScriptDir . "\Beacon_Settings.ini"

; User-defined extra hotkeys (empty = none; the built-in static hotkeys always work)
Global Beacon_MenuHotkey    := ""
Global Beacon_ContextHotkey := ""
Global Beacon_ListenAnnounceEnabled := false
Global Beacon_AnnounceCommandsRate := 0
Global Beacon_AnnounceCommandsAudioOutputId := "__WINDOWS_DEFAULT__"
Global Beacon_AnnounceCommandsTimingMode := "wait"
Global Beacon_InstanceMutexHandle := 0

; Currently registered hotkey strings — tracked so they can be unregistered
; cleanly before registering replacements
Global Beacon_ActiveMenuHotkey    := ""
Global Beacon_ActiveContextHotkey := ""

; AT+App combo map — populated by InitATAppCombos() at startup
Global ATAppCombos := Map()
Global Beacon_SearchEnterTargets := Map()
Global Beacon_SearchEnterHandlerRegistered := false
Global Beacon_CommandIndex := Map()
Global Beacon_CommandIndexBuilt := false
Global Beacon_GlobalCommandIndex := Map()
Global Beacon_ListenHook := ""
Global Beacon_SpeechVoice := ""
Global Beacon_SpeechVoiceCreatedTick := 0
Global Beacon_ScreenReaderSpeechRate := ""
Global Beacon_ScreenReaderSpeechRateSource := ""
Global Beacon_ScreenReaderSpeechRateCheckTick := 0
Global Beacon_LastAnnounceInputTick := 0
Global Beacon_PendingSpeechText := ""
Global Beacon_PendingSpeechQueuedTick := 0
Global Beacon_LastScreenReaderAudioActiveTick := 0
Global Beacon_HeldShortcutHotkeys := Map()
Global Beacon_PendingHeldShortcutSend := ""
Global Beacon_ReplayingHeldShortcut := false
Global Beacon_LastAnnouncedCommand := ""
Global Beacon_LastAnnouncedTick := 0

; -----------------------------------------------------------------------
; Beacon_DetectRunningAT()
;   Returns an array of shorthand keys for every accessibility tool that
;   is currently running as a process.  Possible values:
;   "JAWS", "NVDA", "Narrator", "ZoomText", "Magnifier",
;   "Dragon", "Kurzweil1000", "Kurzweil3000", "IPEVOVisualizer",
;   "ReadAndWrite", "MAGic", "SuperNova", "OSK",
;   "WindowsSpeechRecognition", "VoiceAccess", "NaturalReader"
; -----------------------------------------------------------------------
Beacon_DetectRunningAT() {
    atList := []
    if (WinExist("ahk_exe jfw.exe") || WinExist("ahk_exe jaw64.exe")
     || WinExist("ahk_exe jfw64.exe"))
        atList.Push("JAWS")
    if (WinExist("ahk_exe nvda.exe") || WinExist("ahk_exe nvda_noUIAccess.exe"))
        atList.Push("NVDA")
    if (WinExist("ahk_exe narrator.exe"))
        atList.Push("Narrator")
    if (WinExist("ahk_exe zoomtext.exe") || WinExist("ahk_exe ztvideo.exe")
     || WinExist("ahk_exe ztangelia.exe") || WinExist("ahk_exe zoomdisplay.exe")
     || WinExist("ahk_exe fusion.exe") || WinExist("ahk_exe fsfusion.exe"))
        atList.Push("ZoomText")
    if (WinExist("ahk_exe magnify.exe"))
        atList.Push("Magnifier")
    if (WinExist("ahk_exe VoiceAccess.exe") || WinExist("ahk_exe VoiceAccessUI.exe"))
        atList.Push("VoiceAccess")
    ; Dragon NaturallySpeaking / Dragon Professional
    if (WinExist("ahk_exe natspeak.exe") || WinExist("ahk_exe dragon.exe")
     || WinExist("ahk_exe dragonbar.exe") || WinExist("ahk_exe dns.exe"))
        atList.Push("Dragon")
    ; Kurzweil 1000 (reading software for blind users)
    if (WinExist("ahk_exe kesi1000.exe") || WinExist("ahk_exe k1000.exe")
     || WinExist("ahk_exe kurzweil1000.exe"))
        atList.Push("Kurzweil1000")
    ; Kurzweil 3000 (reading/writing support software)
    if (WinExist("ahk_exe k3w.exe") || WinExist("ahk_exe k3000.exe")
     || WinExist("ahk_exe kesi3000.exe"))
        atList.Push("Kurzweil3000")
    ; IPEVO Visualizer (document camera software)
    if (WinExist("ahk_exe IPEVOVisualizer.exe") || WinExist("ahk_exe Visualizer.exe")
     || WinExist("ahk_exe ipevo.exe"))
        atList.Push("IPEVOVisualizer")
    ; Read&Write by Texthelp (literacy support toolbar)
    if (WinExist("ahk_exe ReadAndWrite.exe") || WinExist("ahk_exe ReadAndWriteforWindows.exe")
     || WinExist("ahk_exe rw.exe") || WinExist("ahk_exe readwrite.exe"))
        atList.Push("ReadAndWrite")
    ; MAGic by Freedom Scientific (screen magnifier)
    if (WinExist("ahk_exe magic.exe") || WinExist("ahk_exe magic64.exe")
     || WinExist("ahk_exe fsmagic.exe"))
        atList.Push("MAGic")
    ; Dolphin SuperNova (combined screen reader + magnifier)
    if (WinExist("ahk_exe supernova.exe") || WinExist("ahk_exe snova.exe")
     || WinExist("ahk_exe dolsnova.exe") || WinExist("ahk_exe dolsupernova.exe"))
        atList.Push("SuperNova")
    if (WinExist("ahk_exe osk.exe"))
        atList.Push("OSK")
    if (WinExist("ahk_exe speechuxwiz.exe") || WinExist("ahk_exe sapisvr.exe")
     || WinExist("ahk_exe wsrec.exe"))
        atList.Push("WindowsSpeechRecognition")
    ; NaturalReader (text-to-speech)
    if (WinExist("ahk_exe NaturalReader.exe") || WinExist("ahk_exe NaturalReader16.exe")
     || WinExist("ahk_exe NaturalReader17.exe") || WinExist("ahk_exe nr.exe"))
        atList.Push("NaturalReader")
    return atList
}

; -----------------------------------------------------------------------
; Beacon_GetATGuideKey(atName)
;   Maps a detected accessibility tool name to its standalone guide key.
; -----------------------------------------------------------------------
Beacon_GetATGuideKey(atName) {
    static atGuideKey := Map(
        "JAWS", "JAWSShortcut",
        "NVDA", "NVDAShortcut",
        "Narrator", "NarratorShortcut",
        "ZoomText", "ZoomTextShortcut",
        "Magnifier", "MagnifierShortcut",
        "VoiceAccess", "VoiceAccessShortcut",
        "Dragon", "DragonShortcut",
        "Kurzweil1000", "Kurzweil1000Shortcut",
        "Kurzweil3000", "Kurzweil3000Shortcut",
        "IPEVOVisualizer", "IPEVOVisualizerShortcut",
        "ReadAndWrite", "ReadAndWriteShortcut",
        "MAGic", "MAGicShortcut",
        "SuperNova", "SuperNovaShortcut",
        "OSK", "OSKShortcut",
        "WindowsSpeechRecognition", "WindowsSpeechRecognitionShortcut",
        "NaturalReader", "NaturalReaderShortcut"
    )
    return atGuideKey.Has(atName) ? atGuideKey[atName] : ""
}

; -----------------------------------------------------------------------
; Beacon_DetectFocusedAccessibilityShortcutType(processName, windowTitle)
;   Detects when the foreground window is the accessibility tool itself.
;   This runs before app+AT overlay logic so focus lookup opens the tool's
;   standalone command guide instead of falling back to the main menu.
; -----------------------------------------------------------------------
Beacon_DetectFocusedAccessibilityShortcutType(processName, windowTitle) {
    proc  := StrLower(processName)
    title := StrLower(windowTitle)

    if (proc = "jfw.exe" || proc = "jaw64.exe" || proc = "jfw64.exe")
        return "JAWSShortcut"
    if (proc = "nvda.exe" || proc = "nvda_nouiaccess.exe")
        return "NVDAShortcut"
    if (proc = "narrator.exe")
        return "NarratorShortcut"
    if (proc = "magnify.exe")
        return "MagnifierShortcut"
    if (proc = "zoomtext.exe" || proc = "ztvideo.exe" || proc = "ztangelia.exe"
     || proc = "zoomdisplay.exe" || proc = "fusion.exe" || proc = "fsfusion.exe")
        return "ZoomTextShortcut"
    if (proc = "voiceaccess.exe" || proc = "voiceaccessui.exe")
        return "VoiceAccessShortcut"
    if (proc = "natspeak.exe" || proc = "dragon.exe" || proc = "dragonbar.exe" || proc = "dns.exe")
        return "DragonShortcut"
    if (proc = "kesi1000.exe" || proc = "k1000.exe" || proc = "kurzweil1000.exe")
        return "Kurzweil1000Shortcut"
    if (proc = "k3w.exe" || proc = "k3000.exe" || proc = "kesi3000.exe")
        return "Kurzweil3000Shortcut"
    if (proc = "ipevovisualizer.exe" || proc = "visualizer.exe" || proc = "ipevo.exe")
        return "IPEVOVisualizerShortcut"
    if (proc = "readandwrite.exe" || proc = "readandwriteforwindows.exe"
     || proc = "readwrite.exe" || proc = "rw.exe")
        return "ReadAndWriteShortcut"
    if (proc = "magic.exe" || proc = "magic64.exe" || proc = "fsmagic.exe")
        return "MAGicShortcut"
    if (proc = "supernova.exe" || proc = "snova.exe" || proc = "dolsnova.exe"
     || proc = "dolsupernova.exe")
        return "SuperNovaShortcut"
    if (proc = "osk.exe")
        return "OSKShortcut"
    if (proc = "speechuxwiz.exe" || proc = "sapisvr.exe" || proc = "wsrec.exe")
        return "WindowsSpeechRecognitionShortcut"
    if (InStr(proc, "naturalreader") || proc = "nr.exe")
        return "NaturalReaderShortcut"

    ; Conservative title fallback for UI surfaces hosted by a generic process.
    if (proc = "applicationframehost.exe" || proc = "shellexperiencehost.exe") {
        if (InStr(title, "voice access"))
            return "VoiceAccessShortcut"
        if (InStr(title, "narrator"))
            return "NarratorShortcut"
        if (InStr(title, "magnifier"))
            return "MagnifierShortcut"
    }

    return ""
}

; -----------------------------------------------------------------------
; Beacon_IsNewerVersion(latest, current)
;   Compares two "X.Y.Z" version strings.  Returns true if latest > current.
;   Handles any number of dot-separated segments.
; -----------------------------------------------------------------------
Beacon_IsNewerVersion(latest, current) {
    lParts := StrSplit(Trim(latest),  ".")
    cParts := StrSplit(Trim(current), ".")
    maxLen := Max(lParts.Length, cParts.Length)
    loop maxLen {
        l := (lParts.Length >= A_Index) ? Integer(lParts[A_Index]) : 0
        c := (cParts.Length >= A_Index) ? Integer(cParts[A_Index]) : 0
        if (l > c)
            return true
        if (l < c)
            return false
    }
    return false  ; Equal versions
}

; -----------------------------------------------------------------------
; Beacon_RemoteFileExists(url)
;   Returns true when the server says the update file exists.  This prevents
;   Beacon from opening a WordPress 404/post page when the manifest and uploaded
;   EXE are out of sync.
; -----------------------------------------------------------------------
Beacon_RemoteFileExists(url) {
    try {
        http := ComObject("WinHttp.WinHttpRequest.5.1")
        http.SetTimeouts(8000, 8000, 8000, 8000)
        http.Open("HEAD", url, false)
        http.Send()
        return (http.Status = 200)
    } catch {
        return false
    }
}

; -----------------------------------------------------------------------
; Beacon_GetUpdateTargetPath()
;   Chooses the stable local EXE path that should be replaced by an update.
;   Prefer the registered startup target, then Documents\Beacon\Beacon.exe,
;   then Beacon.exe in the current folder.
; -----------------------------------------------------------------------
Beacon_GetUpdateTargetPath() {
    regKey := "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run"
    try {
        runCmd := RegRead(regKey, "Beacon")
        if RegExMatch(runCmd, 'i)^"?([^"]*\\Beacon\.exe)"?', &m) {
            if FileExist(m[1])
                return m[1]
        }
    } catch {
    }

    docExe := A_MyDocuments . "\Beacon\Beacon.exe"
    if FileExist(docExe)
        return docExe

    return A_ScriptDir . "\Beacon.exe"
}

Beacon_QuoteArg(arg) {
    return '"' . arg . '"'
}

Beacon_IsRunningWithUIAccessRuntime() {
    return InStr(StrLower(A_AhkPath), "_uia.exe")
}

Beacon_FindUIAccessRuntime() {
    candidates := []

    if (!A_IsCompiled && A_AhkPath != "") {
        SplitPath(A_AhkPath, &ahkName, &ahkDir)
        if (RegExMatch(ahkName, "i)^(AutoHotkey)(32|64)?\.exe$", &m)) {
            arch := m[2]
            if (arch != "")
                candidates.Push(ahkDir . "\AutoHotkey" . arch . "_UIA.exe")
        }
    }

    candidates.Push(A_ProgramFiles . "\AutoHotkey\v2\AutoHotkey64_UIA.exe")
    candidates.Push(A_ProgramFiles . "\AutoHotkey\v2\AutoHotkey32_UIA.exe")
    candidates.Push(A_ProgramFiles . "\AutoHotkey\v2.0.23\AutoHotkey64_UIA.exe")
    candidates.Push(A_ProgramFiles . "\AutoHotkey\v2.0.23\AutoHotkey32_UIA.exe")
    candidates.Push(A_ProgramFiles . "\AutoHotkey\v2.0.22\AutoHotkey64_UIA.exe")
    candidates.Push(A_ProgramFiles . "\AutoHotkey\v2.0.22\AutoHotkey32_UIA.exe")

    for candidate in candidates {
        if FileExist(candidate)
            return candidate
    }
    return ""
}

Beacon_RelaunchWithUIAccessIfAvailable() {
    if (A_IsCompiled)
        return
    if (Beacon_IsRunningWithUIAccessRuntime())
        return
    if (Beacon_IsRelaunchFlagPresent("--beacon-uia"))
        return

    uiaPath := Beacon_FindUIAccessRuntime()
    if (uiaPath = "")
        return

    try {
        Run(Beacon_QuoteArg(uiaPath) . " " . Beacon_QuoteArg(A_ScriptFullPath)
            . " --beacon-uia", A_ScriptDir)
        ExitApp()
    } catch {
    }
}

Beacon_GetInstanceMutexName() {
    return "Local\EyeTechAnalytics_Beacon_ShortcutGuide"
}

Beacon_IsExistingInstanceRunning() {
    mutexHandle := DllCall("OpenMutex", "UInt", 0x00100000, "Int", false,
        "Str", Beacon_GetInstanceMutexName(), "Ptr")
    if (!mutexHandle)
        return false

    DllCall("CloseHandle", "Ptr", mutexHandle)
    return true
}

Beacon_EnsureSingleInstance() {
    global Beacon_InstanceMutexHandle

    mutexHandle := DllCall("CreateMutex", "Ptr", 0, "Int", true,
        "Str", Beacon_GetInstanceMutexName(), "Ptr")
    if (!mutexHandle)
        return

    if (A_LastError = 183) { ; ERROR_ALREADY_EXISTS
        DllCall("CloseHandle", "Ptr", mutexHandle)
        ExitApp()
    }

    Beacon_InstanceMutexHandle := mutexHandle
    OnExit(Beacon_ReleaseInstanceMutex)
}

Beacon_ReleaseInstanceMutex(*) {
    global Beacon_InstanceMutexHandle
    if (!Beacon_InstanceMutexHandle)
        return

    DllCall("ReleaseMutex", "Ptr", Beacon_InstanceMutexHandle)
    DllCall("CloseHandle", "Ptr", Beacon_InstanceMutexHandle)
    Beacon_InstanceMutexHandle := 0
}

Beacon_GetScriptRunCommand(scriptPath, extraArgs := "") {
    runCmd := Beacon_QuoteArg(A_AhkPath) . " " . Beacon_QuoteArg(scriptPath)
    if (extraArgs != "")
        runCmd .= " " . extraArgs
    return runCmd
}

Beacon_IsRelaunchFlagPresent(flagName) {
    for arg in A_Args {
        if (StrLower(arg) = StrLower(flagName))
            return true
    }
    return false
}

; -----------------------------------------------------------------------
; Beacon_DownloadAndInstallUpdate(downloadURL, latestVersion)
;   Downloads the versioned EXE to a temp file, then launches a hidden helper
;   script that waits for Beacon to close, copies it over Beacon.exe, and restarts
;   Beacon.  This keeps the installed file name stable while avoiding Windows'
;   lock on the running executable.
; -----------------------------------------------------------------------
Beacon_DownloadAndInstallUpdate(downloadURL, latestVersion) {
    tempDir := A_Temp . "\BeaconUpdate"
    tempExe := tempDir . "\Beacon." . latestVersion . ".download.exe"
    helperPath := tempDir . "\Install-BeaconUpdate.ps1"
    targetExe := Beacon_GetUpdateTargetPath()

    try {
        DirCreate(tempDir)
        if FileExist(tempExe)
            FileDelete(tempExe)

        Download(downloadURL, tempExe)

        if (!FileExist(tempExe) || FileGetSize(tempExe) < 100000)
            throw Error("The downloaded update file is missing or too small.")

        scriptText := ""
        scriptText .= "param([int]$BeaconPid, [string]$Source, [string]$Target, [string]$OldCurrent)`r`n"
        scriptText .= "$ErrorActionPreference = 'Stop'`r`n"
        scriptText .= "try { Wait-Process -Id $BeaconPid -Timeout 30 -ErrorAction SilentlyContinue } catch { }`r`n"
        scriptText .= "Start-Sleep -Milliseconds 500`r`n"
        scriptText .= "$targetDir = Split-Path -Parent $Target`r`n"
        scriptText .= "New-Item -ItemType Directory -Path $targetDir -Force | Out-Null`r`n"
        scriptText .= "$backup = $Target + '.previous'`r`n"
        scriptText .= "$ok = $false`r`n"
        scriptText .= "for ($i = 0; $i -lt 30; $i++) {`r`n"
        scriptText .= "  try {`r`n"
        scriptText .= "    if (Test-Path -LiteralPath $Target) { Copy-Item -LiteralPath $Target -Destination $backup -Force }`r`n"
        scriptText .= "    Copy-Item -LiteralPath $Source -Destination $Target -Force`r`n"
        scriptText .= "    $ok = $true; break`r`n"
        scriptText .= "  } catch { Start-Sleep -Milliseconds 500 }`r`n"
        scriptText .= "}`r`n"
        scriptText .= "if (!$ok) { exit 1 }`r`n"
        scriptText .= "try { Remove-Item -LiteralPath $Source -Force -ErrorAction SilentlyContinue } catch { }`r`n"
        scriptText .= "try { if ($OldCurrent -and ($OldCurrent -ne $Target) -and ((Split-Path -Leaf $OldCurrent) -ne 'Beacon.exe') -and (Test-Path -LiteralPath $OldCurrent)) { Remove-Item -LiteralPath $OldCurrent -Force -ErrorAction SilentlyContinue } } catch { }`r`n"
        scriptText .= "Start-Process -FilePath $Target`r`n"

        if FileExist(helperPath)
            FileDelete(helperPath)
        FileAppend(scriptText, helperPath, "UTF-8")

        psExe := A_WinDir . "\System32\WindowsPowerShell\v1.0\powershell.exe"
        currentPID := DllCall("GetCurrentProcessId", "UInt")
        cmd := Beacon_QuoteArg(psExe)
            . " -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File " . Beacon_QuoteArg(helperPath)
            . " -BeaconPid " . currentPID
            . " -Source " . Beacon_QuoteArg(tempExe)
            . " -Target " . Beacon_QuoteArg(targetExe)
            . " -OldCurrent " . Beacon_QuoteArg(A_ScriptFullPath)

        MsgBox("Beacon has downloaded the update and will now close, replace:`n"
            . targetExe . "`n`nand restart Beacon using the stable file name Beacon.exe.",
            "Beacon Update Ready", 64|4096)
        Run(cmd, , "Hide")
        ExitApp()
    } catch as err {
        MsgBox("Beacon could not install the update automatically:`n"
            . err.Message . "`n`nDownload URL:`n" . downloadURL,
            "Beacon Update Failed", 48|4096)
    }
}

; -----------------------------------------------------------------------
; Beacon_CheckForUpdate()
;   Fetches Beacon_version.txt from the download server and compares it
;   to Beacon_Version.  If a newer version is available, downloads the
;   versioned EXE and replaces the local stable Beacon.exe after restart.
;
;   The version manifest is a plain-text file containing only the latest
;   version string, e.g.:  4.5
;   Host it at:
;     https://eyetechanalytics.com/wp-content/uploads/downloads/Beacon_version.txt
;
;   The versioned download URL is built as:
;     https://eyetechanalytics.com/wp-content/uploads/downloads/Beacon.X.Y.Z.exe
; -----------------------------------------------------------------------
Beacon_CheckForUpdate() {
    global Beacon_Version
    versionURL  := "https://eyetechanalytics.com/wp-content/uploads/downloads/Beacon_version.txt"
    downloadBase := "https://eyetechanalytics.com/wp-content/uploads/downloads/"

    try {
        http := ComObject("WinHttp.WinHttpRequest.5.1")
        http.SetTimeouts(8000, 8000, 8000, 8000)     ; must be set before Open()
        http.Open("GET", versionURL . "?t=" . A_TickCount, false)  ; false = synchronous; cache-bust
        http.Send()

        if (http.Status != 200)
            return  ; Server returned an error — silently ignore

        latestVersion := Trim(http.ResponseText)

        ; Basic sanity check — should look like digits and dots only
        if (!RegExMatch(latestVersion, "^\d+(\.\d+)*$"))
            return

        if (!Beacon_IsNewerVersion(latestVersion, Beacon_Version))
            return  ; Already up to date

        ; A newer version is available — prompt the user (non-blocking MsgBox)
        downloadURL := downloadBase . "Beacon." . latestVersion . ".exe"
        if (!Beacon_RemoteFileExists(downloadURL)) {
            MsgBox("Beacon found version " . latestVersion . " in the update manifest, "
                . "but the expected download file was not found:`n`n"
                . downloadURL . "`n`n"
                . "Please update Beacon_version.txt or upload the matching EXE.",
                "Beacon Update Not Available", 48|4096)
            return
        }

        result := MsgBox(
            "A new version of Beacon is available!`n`n"
            . "Your version:   " . Beacon_Version . "`n"
            . "Latest version: " . latestVersion . "`n`n"
            . "Would you like Beacon to download and install the update now?`n`n"
            . "Beacon will close, replace the local Beacon.exe, and restart.",
            "Beacon Update Available", 4|64|4096)   ; Yes/No, info icon, always on top

        if (result = "Yes")
            Beacon_DownloadAndInstallUpdate(downloadURL, latestVersion)

    } catch {
        ; Network unavailable or server unreachable — silently ignore
    }
}

; -----------------------------------------------------------------------
; InitATAppCombos()
;   Builds the ATAppCombos nested Map that pairs each AT tool with the
;   app-specific content callbacks it supports.
;
;   Structure:  ATAppCombos[AT_Key][AppShortcutType] := ContentCallback
;
;   The special key "_general" is used as a fallback when no entry exists
;   for the specific focused app but a general AT overlay makes sense.
; -----------------------------------------------------------------------
InitATAppCombos() {
    global ATAppCombos

    ; ── JAWS ────────────────────────────────────────────────────────────
    jawsMap := Map()
    jawsMap["WordShortcut"]               := GetJAWS_WordATContent
    jawsMap["ExcelShortcut"]              := GetJAWS_ExcelATContent
    jawsMap["OutlookShortcut"]            := GetJAWS_OutlookATContent
    jawsMap["PowerPointShortcut"]         := GetJAWS_OfficeGeneralATContent
    jawsMap["OneNoteOnlineShortcut"]      := GetJAWS_OfficeGeneralATContent
    jawsMap["AccessShortcut"]             := GetJAWS_OfficeGeneralATContent
    ; All browser variants share the same virtual-cursor content
    for bType in ["BrowserShortcut","GoogleDocsShortcut","GoogleSheetsShortcut",
                  "GoogleSlidesShortcut","GmailShortcut","GoogleMeetShortcut",
                  "GoogleDriveShortcut","GoogleCalendarShortcut","GoogleChatShortcut",
                  "FacebookShortcut","XShortcut","LinkedInShortcut","GitHubWebShortcut",
                  "NotionShortcut","DropboxShortcut","FigmaShortcut","TrelloShortcut",
                  "CanvaShortcut","MondayShortcut",
                  "YouTubeShortcut","YouTubeMusicShortcut","SharePointOnlineShortcut",
                  "TeamsWebShortcut","TeamsShortcut"] {
        jawsMap[bType] := GetJAWS_BrowserATContent
    }
    ATAppCombos["JAWS"] := jawsMap

    ; ── NVDA ────────────────────────────────────────────────────────────
    nvdaMap := Map()
    nvdaMap["WordShortcut"]               := GetNVDA_WordATContent
    nvdaMap["ExcelShortcut"]              := GetNVDA_ExcelATContent
    nvdaMap["OutlookShortcut"]            := GetNVDA_OutlookATContent
    nvdaMap["PowerPointShortcut"]         := GetNVDA_OfficeGeneralATContent
    nvdaMap["OneNoteOnlineShortcut"]      := GetNVDA_OfficeGeneralATContent
    for bType in ["BrowserShortcut","GoogleDocsShortcut","GoogleSheetsShortcut",
                  "GoogleSlidesShortcut","GmailShortcut","GoogleMeetShortcut",
                  "GoogleDriveShortcut","GoogleCalendarShortcut","GoogleChatShortcut",
                  "FacebookShortcut","XShortcut","LinkedInShortcut","GitHubWebShortcut",
                  "NotionShortcut","DropboxShortcut","FigmaShortcut","TrelloShortcut",
                  "CanvaShortcut","MondayShortcut",
                  "YouTubeShortcut","YouTubeMusicShortcut","SharePointOnlineShortcut",
                  "TeamsWebShortcut","TeamsShortcut"] {
        nvdaMap[bType] := GetNVDA_BrowserATContent
    }
    ATAppCombos["NVDA"] := nvdaMap

    ; ── Narrator ────────────────────────────────────────────────────────
    narratorMap := Map()
    narratorMap["WordShortcut"]           := GetNarrator_WordATContent
    narratorMap["ExcelShortcut"]          := GetNarrator_ExcelATContent
    narratorMap["OutlookShortcut"]        := GetNarrator_OutlookATContent
    narratorMap["PowerPointShortcut"]     := GetNarrator_OfficeGeneralATContent
    for bType in ["BrowserShortcut","GoogleDocsShortcut","GoogleSheetsShortcut",
                  "GoogleSlidesShortcut","GmailShortcut","GoogleMeetShortcut",
                  "GoogleDriveShortcut","GoogleCalendarShortcut","GoogleChatShortcut",
                  "FacebookShortcut","XShortcut","LinkedInShortcut","GitHubWebShortcut",
                  "NotionShortcut","DropboxShortcut","FigmaShortcut","TrelloShortcut",
                  "CanvaShortcut","MondayShortcut",
                  "YouTubeShortcut","YouTubeMusicShortcut","SharePointOnlineShortcut",
                  "TeamsWebShortcut","TeamsShortcut"] {
        narratorMap[bType] := GetNarrator_BrowserATContent
    }
    ATAppCombos["Narrator"] := narratorMap

    ; ── ZoomText ────────────────────────────────────────────────────────
    ; ZoomText has app-specific features (AppReader, DocReader) for text apps
    zoomMap := Map()
    zoomMap["WordShortcut"]               := GetZoomText_WordATContent
    zoomMap["ExcelShortcut"]              := GetZoomText_GeneralATContent
    zoomMap["OutlookShortcut"]            := GetZoomText_GeneralATContent
    zoomMap["_general"]                   := GetZoomText_GeneralATContent
    ATAppCombos["ZoomText"] := zoomMap

    ; ── Windows Magnifier ───────────────────────────────────────────────
    magMap := Map()
    magMap["_general"]                    := GetMagnifier_ReminderATContent
    ATAppCombos["Magnifier"] := magMap

    ; ── Dragon NaturallySpeaking ─────────────────────────────────────────
    dragonMap := Map()
    dragonMap["WordShortcut"]             := GetDragon_WordATContent
    dragonMap["ExcelShortcut"]            := GetDragon_OfficeATContent
    dragonMap["OutlookShortcut"]          := GetDragon_OutlookATContent
    dragonMap["PowerPointShortcut"]       := GetDragon_OfficeATContent
    for bType in ["BrowserShortcut","GoogleDocsShortcut","GoogleSheetsShortcut",
                  "GoogleSlidesShortcut","GmailShortcut","GoogleMeetShortcut",
                  "GoogleDriveShortcut","GoogleCalendarShortcut","GoogleChatShortcut",
                  "FacebookShortcut","XShortcut","LinkedInShortcut","GitHubWebShortcut",
                  "NotionShortcut","DropboxShortcut","FigmaShortcut","TrelloShortcut",
                  "CanvaShortcut","MondayShortcut",
                  "YouTubeShortcut","SharePointOnlineShortcut"] {
        dragonMap[bType] := GetDragon_BrowserATContent
    }
    dragonMap["_general"]                 := GetDragon_GeneralATContent
    ATAppCombos["Dragon"] := dragonMap

    ; ── Kurzweil 1000 ────────────────────────────────────────────────────
    k1Map := Map()
    k1Map["_general"]                     := GetKurzweil1000_GeneralATContent
    ATAppCombos["Kurzweil1000"] := k1Map

    ; ── Kurzweil 3000 ────────────────────────────────────────────────────
    k3Map := Map()
    k3Map["WordShortcut"]                 := GetKurzweil3000_WordATContent
    k3Map["_general"]                     := GetKurzweil3000_GeneralATContent
    ATAppCombos["Kurzweil3000"] := k3Map

    ; ── IPEVO Visualizer ─────────────────────────────────────────────────
    ; IPEVO is a standalone document camera app — no app-specific overlays
    ATAppCombos["IPEVOVisualizer"] := Map()

    ; ── NVDA + LibreOffice ────────────────────────────────────────────────
    ; NVDA is by far the most used AT with LibreOffice; full support via UNO API
    nvdaMap["LibreWriterShortcut"]        := GetNVDA_LibreWriterATContent
    nvdaMap["LibreCalcShortcut"]          := GetNVDA_LibreCalcATContent
    nvdaMap["LibreImpressShortcut"]       := GetNVDA_LibreWriterATContent  ; reading/structure overlap
    ATAppCombos["NVDA"] := nvdaMap   ; re-assign to pick up new entries

    ; ── JAWS + LibreOffice ────────────────────────────────────────────────
    jawsMap["LibreWriterShortcut"]        := GetJAWS_LibreWriterATContent
    jawsMap["LibreCalcShortcut"]          := GetJAWS_LibreCalcATContent
    jawsMap["LibreImpressShortcut"]       := GetJAWS_LibreWriterATContent  ; virtual cursor overlap
    ATAppCombos["JAWS"] := jawsMap   ; re-assign to pick up new entries

    ; ── Narrator + LibreOffice ────────────────────────────────────────────
    ; Narrator has basic support; use general reminder content
    narratorMap["LibreWriterShortcut"]    := GetNarrator_OfficeGeneralATContent
    narratorMap["LibreCalcShortcut"]      := GetNarrator_ExcelATContent
    ATAppCombos["Narrator"] := narratorMap

    ; ── Read&Write by Texthelp ────────────────────────────────────────────
    ; R&W is app-agnostic; provide the general coexistence overlay for any app
    rwMap := Map()
    rwMap["_general"]                     := GetReadAndWrite_GeneralATContent
    rwMap["WordShortcut"]                 := GetReadAndWrite_GeneralATContent
    rwMap["ExcelShortcut"]                := GetReadAndWrite_GeneralATContent
    rwMap["AdobeReaderShortcut"]          := GetReadAndWrite_GeneralATContent
    for bType in ["BrowserShortcut","GoogleDocsShortcut","GoogleSheetsShortcut",
                  "GoogleSlidesShortcut","GmailShortcut","GoogleDriveShortcut",
                  "GoogleCalendarShortcut","GoogleChatShortcut","FacebookShortcut",
                  "XShortcut","LinkedInShortcut","GitHubWebShortcut",
                  "NotionShortcut","DropboxShortcut","FigmaShortcut","TrelloShortcut",
                  "CanvaShortcut","MondayShortcut"] {
        rwMap[bType] := GetReadAndWrite_GeneralATContent
    }
    ATAppCombos["ReadAndWrite"] := rwMap

    ; ── MAGic by Freedom Scientific ───────────────────────────────────────
    ; MAGic is purely a magnifier; general overlay explains JAWS/NVDA coexistence
    magicMap := Map()
    magicMap["_general"]                  := GetMAGic_GeneralATContent
    ATAppCombos["MAGic"] := magicMap

    ; ── Dolphin SuperNova ─────────────────────────────────────────────────
    ; SuperNova is a combined reader+magnifier — general overlay covers all apps
    snovaMap := Map()
    snovaMap["_general"]                  := GetSuperNova_GeneralATContent
    snovaMap["WordShortcut"]              := GetSuperNova_GeneralATContent
    snovaMap["ExcelShortcut"]             := GetSuperNova_GeneralATContent
    for bType in ["BrowserShortcut","GoogleDocsShortcut","GmailShortcut",
                  "GoogleDriveShortcut","GoogleCalendarShortcut","GoogleChatShortcut",
                  "FacebookShortcut","XShortcut","LinkedInShortcut","GitHubWebShortcut",
                  "NotionShortcut","DropboxShortcut","FigmaShortcut","TrelloShortcut",
                  "CanvaShortcut","MondayShortcut"] {
        snovaMap[bType] := GetSuperNova_GeneralATContent
    }
    ATAppCombos["SuperNova"] := snovaMap

    ; ── NaturalReader ─────────────────────────────────────────────────────
    ; NaturalReader is a standalone TTS tool; no app-specific overlays
    ATAppCombos["NaturalReader"] := Map()
}

; -----------------------------------------------------------------------
; Beacon_IsInStartup()
;   Returns true if Beacon is registered in the Windows Run key.
; -----------------------------------------------------------------------
Beacon_IsInStartup() {
    try {
        RegRead("HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run", "Beacon")
        return true
    } catch {
        return false
    }
}

; -----------------------------------------------------------------------
; Beacon_SetStartup(enable)
;   On enable: moves Beacon to Documents\Beacon\ (if not already there),
;   removes originals from the previous location, then registers the new
;   location in the HKCU Run key.
;   On disable: removes only the registry key; files in Documents are kept.
; -----------------------------------------------------------------------
Beacon_SetStartup(enable) {
    regKey  := "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run"
    if (enable) {
        destDir  := A_MyDocuments . "\Beacon"
        destFile := destDir . (A_IsCompiled ? "\Beacon.exe" : "\Beacon.ahk")

        ; Move to Documents only when not already running from there
        if (A_ScriptDir != destDir) {
            ; --- Step 1: copy files to Documents\Beacon\ ---
            oldIniPath := A_ScriptDir . "\Beacon_Settings.ini"
            try {
                DirCreate(destDir)
                if (A_IsCompiled) {
                    FileCopy(A_ScriptFullPath, destFile, 1)
                } else {
                    Loop Files, A_ScriptDir . "\*.ahk" {
                        FileCopy(A_LoopFilePath, destDir . "\" . A_LoopFileName, 1)
                    }
                }
                ; Carry over saved settings (hotkeys, etc.) to the new location
                ; so the user's preferences survive the move.
                if FileExist(oldIniPath)
                    FileCopy(oldIniPath, destDir . "\Beacon_Settings.ini", 1)
            } catch as err {
                MsgBox("Beacon could not be moved to your Documents folder:`n" . err.Message
                    . "`n`nStartup registration was not changed.", "Beacon Settings", 48|4096)
                return
            }

            ; --- Step 2: write registry entry pointing to the new location ---
            ; Done here (before any exit) so the key is in place regardless of
            ; which branch runs below.
            runCmd := A_IsCompiled
                ? ('"' . destFile . '"')
                : Beacon_GetScriptRunCommand(destFile)
            try {
                RegWrite(runCmd, "REG_SZ", regKey, "Beacon")
            } catch {
                MsgBox("Unable to write to the registry.`nTry running Beacon as administrator.",
                    "Beacon Settings", 48|4096)
                return
            }

            ; --- Step 3: clean up originals ---
            if (A_IsCompiled) {
                ; Store the old .exe path so the new instance can delete it once
                ; this process has exited and released the file lock.
                try {
                    RegWrite(A_ScriptFullPath, "REG_SZ",
                        "HKEY_CURRENT_USER\Software\Beacon", "PendingCleanup")
                } catch {
                    ; Non-critical — cleanup just won't happen automatically
                }
                ; The .ini is never locked — delete it immediately
                try {
                    if FileExist(oldIniPath)
                        FileDelete(oldIniPath)
                } catch {
                    ; Non-critical; ignore
                }
                ; Launch Beacon from the new location with a /postmove flag so
                ; the new instance knows to run cleanup and show a confirmation,
                ; then exit this (now-replaced) instance.
                Run('"' . destFile . '" /postmove')
                ExitApp()
            } else {
                ; .ahk files and the .ini are not locked — delete immediately
                cleanupNote := ""
                try {
                    Loop Files, A_ScriptDir . "\*.ahk" {
                        FileDelete(A_LoopFilePath)
                    }
                    if FileExist(oldIniPath)
                        FileDelete(oldIniPath)
                    cleanupNote := "`n`nThe original script files have been removed from their previous location."
                } catch {
                    cleanupNote := "`n`nNote: Some original files could not be removed from their previous location."
                }
                MsgBox("Beacon has been moved to:`n" . destDir
                    . "`n`nWindows will launch Beacon from that location at startup."
                    . cleanupNote, "Beacon Settings", 64|4096)
            }
        }

        ; If already running from destDir (compiled or script), just ensure the
        ; registry key is present and up to date.  The move block above only
        ; runs when A_ScriptDir != destDir and calls ExitApp() for the compiled
        ; case, so this branch is only reached when no move was necessary.
        if (A_ScriptDir = destDir) {
            runCmd := A_IsCompiled
                ? ('"' . destFile . '"')
                : Beacon_GetScriptRunCommand(destFile)
            try {
                RegWrite(runCmd, "REG_SZ", regKey, "Beacon")
            } catch {
                MsgBox("Unable to write to the registry.`nTry running Beacon as administrator.",
                    "Beacon Settings", 48|4096)
            }
        }
    } else {
        ; Disable: remove registry entry only — leave files in Documents untouched
        try {
            RegDelete(regKey, "Beacon")
        } catch {
            ; Key may already be absent — ignore
        }
    }
}

; -----------------------------------------------------------------------
; Beacon_LoadSettings()
;   Reads saved hotkey preferences from Beacon_Settings.ini.
;   Missing keys fall back to the global defaults above.
; -----------------------------------------------------------------------
Beacon_LoadSettings() {
    global Beacon_MenuHotkey, Beacon_ContextHotkey, Beacon_ListenAnnounceEnabled
    global Beacon_AnnounceCommandsRate, Beacon_AnnounceCommandsAudioOutputId
    global Beacon_AnnounceCommandsTimingMode
    global Beacon_SettingsFile
    try {
        v := IniRead(Beacon_SettingsFile, "Hotkeys", "MenuHotkey", "")
        Beacon_MenuHotkey := v
    } catch {
    }
    try {
        v := IniRead(Beacon_SettingsFile, "Hotkeys", "ContextualHotkey", "")
        Beacon_ContextHotkey := v
    } catch {
    }
    try {
        v := IniRead(Beacon_SettingsFile, "Features", "AnnounceCommandsEnabled", "__MISSING__")
        if (v = "__MISSING__")
            v := IniRead(Beacon_SettingsFile, "Features", "ListenAnnounceEnabled", "0")
        Beacon_ListenAnnounceEnabled := (v = "1")
    } catch {
    }
    try {
        v := IniRead(Beacon_SettingsFile, "Features", "AnnounceCommandsRate", "0")
        Beacon_AnnounceCommandsRate := Beacon_ClampInteger(v, -10, 10, 0)
    } catch {
    }
    try {
        Beacon_AnnounceCommandsAudioOutputId :=
            IniRead(Beacon_SettingsFile, "Features", "AnnounceCommandsAudioOutputId",
                "__WINDOWS_DEFAULT__")
    } catch {
    }
    try {
        v := IniRead(Beacon_SettingsFile, "Features", "AnnounceCommandsTimingMode", "wait")
        Beacon_AnnounceCommandsTimingMode := Beacon_NormalizeAnnounceTimingMode(v)
    } catch {
    }
}

; -----------------------------------------------------------------------
; Beacon_SaveSettings(menuHk, contextHk, announceCommandsEnabled, announceCommandsRate, audioOutputId, timingMode)
;   Writes hotkey preferences to Beacon_Settings.ini.
; -----------------------------------------------------------------------
Beacon_SaveSettings(menuHk, contextHk, announceCommandsEnabled := false, announceCommandsRate := 0,
    audioOutputId := "", timingMode := "wait") {
    global Beacon_SettingsFile
    try {
        IniWrite(menuHk,    Beacon_SettingsFile, "Hotkeys", "MenuHotkey")
        IniWrite(contextHk, Beacon_SettingsFile, "Hotkeys", "ContextualHotkey")
        IniWrite(announceCommandsEnabled ? "1" : "0",
            Beacon_SettingsFile, "Features", "AnnounceCommandsEnabled")
        IniWrite(Beacon_ClampInteger(announceCommandsRate, -10, 10, 0),
            Beacon_SettingsFile, "Features", "AnnounceCommandsRate")
        IniWrite(audioOutputId, Beacon_SettingsFile, "Features", "AnnounceCommandsAudioOutputId")
        IniWrite(Beacon_NormalizeAnnounceTimingMode(timingMode),
            Beacon_SettingsFile, "Features", "AnnounceCommandsTimingMode")
    } catch {
    }
}

Beacon_NormalizeAnnounceTimingMode(value) {
    mode := StrLower(Trim(value))
    if (mode = "speak_first")
        return "speak_first"
    return "wait"
}

Beacon_ClampInteger(value, minValue, maxValue, defaultValue := 0) {
    try {
        n := Integer(value)
    } catch {
        n := defaultValue
    }
    if (n < minValue)
        return minValue
    if (n > maxValue)
        return maxValue
    return n
}

; -----------------------------------------------------------------------
; Beacon_ApplyHotkeys()
;   Unregisters the previously active hotkeys, then registers the current
;   Beacon_MenuHotkey and Beacon_ContextHotkey values.
;   Called once at startup and again whenever the user saves new hotkeys.
; -----------------------------------------------------------------------
Beacon_ApplyHotkeys() {
    global Beacon_MenuHotkey, Beacon_ContextHotkey
    global Beacon_ActiveMenuHotkey, Beacon_ActiveContextHotkey

    ; Remove old registrations so the key combination is freed
    if (Beacon_ActiveMenuHotkey != "") {
        try {
            Hotkey(Beacon_ActiveMenuHotkey, "Off")
        } catch {
        }
        Beacon_ActiveMenuHotkey := ""
    }
    if (Beacon_ActiveContextHotkey != "") {
        try {
            Hotkey(Beacon_ActiveContextHotkey, "Off")
        } catch {
        }
        Beacon_ActiveContextHotkey := ""
    }

    ; Register menu hotkey
    if (Beacon_MenuHotkey != "") {
        try {
            Hotkey(Beacon_MenuHotkey, (*) => ShowKeyboardMenu())
            Beacon_ActiveMenuHotkey := Beacon_MenuHotkey
        } catch {
            MsgBox("Could not register menu hotkey: " . Beacon_MenuHotkey
                . "`nIt may conflict with another application.",
                "Beacon Settings", 48)
        }
    }

    ; Register contextual hotkey (may be empty if user left it blank)
    if (Beacon_ContextHotkey != "") {
        try {
            Hotkey(Beacon_ContextHotkey, (*) => ShowContextualShortcuts())
            Beacon_ActiveContextHotkey := Beacon_ContextHotkey
        } catch {
            MsgBox("Could not register contextual hotkey: " . Beacon_ContextHotkey
                . "`nIt may conflict with another application.",
                "Beacon Settings", 48)
        }
    }
}

; -----------------------------------------------------------------------
; Listen-and-announce support
;   Passive first version: announces recognized shortcut-style commands for
;   the focused app. It intentionally does not report invalid commands during
;   normal use, so ordinary typing is not punished with noise.
; -----------------------------------------------------------------------
Beacon_ApplyListenAnnounce() {
    global Beacon_ListenAnnounceEnabled

    Beacon_StopListenAnnounce()

    if (Beacon_ListenAnnounceEnabled)
        Beacon_StartListenAnnounce()
}

Beacon_StartListenAnnounce() {
    global Beacon_ListenHook, Beacon_CommandIndexBuilt

    if (IsObject(Beacon_ListenHook)) {
        try {
            if (Beacon_ListenHook.InProgress)
                return
        } catch {
        }
    }

    if (!Beacon_CommandIndexBuilt)
        Beacon_BuildCommandIndex()

    try {
        ih := InputHook("V")
        ih.KeyOpt("{All}", "N")
        ih.OnKeyDown := Beacon_ListenAnnounce_KeyDown
        ih.OnKeyUp   := Beacon_ListenAnnounce_KeyUp
        ih.KeysDown := Map()
        ih.Start()
        Beacon_ListenHook := ih
        Beacon_RegisterSpeechStopHotkeys()
        Beacon_RegisterHeldShortcutHotkeys()
    } catch as err {
        Beacon_ListenHook := ""
        MsgBox("Could not start Listen and Announce."
            . "`n`n" . err.Message,
            "Beacon Settings", 48)
    }
}

Beacon_StopListenAnnounce() {
    global Beacon_ListenHook

    if (IsObject(Beacon_ListenHook)) {
        try {
            if (Beacon_ListenHook.InProgress)
                Beacon_ListenHook.Stop()
        } catch {
        }
    }
    Beacon_ListenHook := ""
    Beacon_UnregisterSpeechStopHotkeys()
    Beacon_UnregisterHeldShortcutHotkeys()
    Beacon_ClearPendingSpeech()
    Beacon_ClearPendingHeldShortcut()
}

Beacon_RegisterSpeechStopHotkeys() {
    ctrlHotkeys := []
    ctrlHotkeys.Push("~*LControl")
    ctrlHotkeys.Push("~*RControl")

    for hk in ctrlHotkeys {
        try {
            Hotkey(hk, Beacon_StopSpeechHotkey, "On")
        } catch {
        }
    }
}

Beacon_UnregisterSpeechStopHotkeys() {
    ctrlHotkeys := []
    ctrlHotkeys.Push("~*LControl")
    ctrlHotkeys.Push("~*RControl")

    for hk in ctrlHotkeys {
        try {
            Hotkey(hk, "Off")
        } catch {
        }
    }
}

Beacon_StopSpeechHotkey(*) {
    Beacon_StopSpeech()
}

Beacon_RegisterHeldShortcutHotkeys() {
    global Beacon_AnnounceCommandsTimingMode
    global Beacon_CommandIndex, Beacon_GlobalCommandIndex, Beacon_HeldShortcutHotkeys

    Beacon_UnregisterHeldShortcutHotkeys()

    if (Beacon_AnnounceCommandsTimingMode != "speak_first")
        return

    commands := Map()
    for normalized, desc in Beacon_GlobalCommandIndex {
        if (Beacon_IsHoldReplayEligibleCommand(normalized))
            commands[normalized] := true
    }
    for guideKey, appCommands in Beacon_CommandIndex {
        for normalized, desc in appCommands {
            if (Beacon_IsHoldReplayEligibleCommand(normalized))
                commands[normalized] := true
        }
    }

    for normalized, unused in commands {
        hk := Beacon_CommandToHotkeyString(normalized)
        if (hk = "")
            continue
        try {
            Hotkey(hk, Beacon_HeldShortcutHotkey.Bind(normalized), "On")
            Beacon_HeldShortcutHotkeys[hk] := true
        } catch {
        }
    }
}

Beacon_UnregisterHeldShortcutHotkeys() {
    global Beacon_HeldShortcutHotkeys

    for hk, unused in Beacon_HeldShortcutHotkeys {
        try {
            Hotkey(hk, "Off")
        } catch {
        }
    }
    Beacon_HeldShortcutHotkeys := Map()
}

Beacon_HeldShortcutHotkey(normalizedCommand, *) {
    global Beacon_ReplayingHeldShortcut

    if (Beacon_ReplayingHeldShortcut)
        return

    Beacon_ClearPendingHeldShortcut()

    sendText := Beacon_CommandToSendString(normalizedCommand)
    if (sendText = "")
        return

    announcement := Beacon_GetAnnouncementForCommand(normalizedCommand)
    if (announcement = "" || Beacon_ShouldSuppressAnnouncement(normalizedCommand)) {
        Beacon_SendHeldShortcut(sendText)
        return
    }

    Beacon_ClearPendingSpeech()
    Beacon_SpeakAndWait(announcement)
    Beacon_SendHeldShortcut(sendText)
}

Beacon_IsHoldReplayEligibleCommand(normalizedCommand) {
    parts := StrSplit(normalizedCommand, " + ")
    if (parts.Length < 2)
        return false

    if (InStr(normalizedCommand, "Windows + "))
        return false
    if (normalizedCommand = "Ctrl + Alt + Delete")
        return false

    key := parts[parts.Length]
    if (RegExMatch(key, "i)^(Up|Down|Left|Right)$"))
        return false

    return (InStr(normalizedCommand, "Ctrl + ")
        || InStr(normalizedCommand, "Alt + ")
        || InStr(normalizedCommand, "Shift + "))
}

Beacon_CommandToHotkeyString(normalizedCommand) {
    parts := StrSplit(normalizedCommand, " + ")
    mods := ""
    key := ""

    for part in parts {
        if (part = "Ctrl")
            mods .= "^"
        else if (part = "Alt")
            mods .= "!"
        else if (part = "Shift")
            mods .= "+"
        else if (part = "Windows")
            mods .= "#"
        else
            key := Beacon_CommandKeyToHotkeyKey(part)
    }

    if (key = "")
        return ""

    return "$" . mods . key
}

Beacon_CommandKeyToHotkeyKey(key) {
    if (RegExMatch(key, "i)^[A-Z0-9]$"))
        return StrLower(key)
    if (RegExMatch(key, "i)^F([1-9]|1[0-2])$"))
        return key

    static hotkeyKeys := Map(
        "Escape", "Esc",
        "Enter", "Enter",
        "Tab", "Tab",
        "Space", "Space",
        "Backspace", "Backspace",
        "Delete", "Delete",
        "Home", "Home",
        "End", "End",
        "Page Up", "PgUp",
        "Page Down", "PgDn",
        "Insert", "Insert",
        "AppsKey", "AppsKey",
        "Print Screen", "PrintScreen"
    )

    return hotkeyKeys.Has(key) ? hotkeyKeys[key] : ""
}

Beacon_GetAnnouncementForCommand(normalizedCommand) {
    global Beacon_CommandIndex, Beacon_GlobalCommandIndex

    if (Beacon_GlobalCommandIndex.Has(normalizedCommand))
        return Beacon_GlobalCommandIndex[normalizedCommand]

    hwnd := WinExist("A")
    if (!hwnd)
        return ""

    processName := ""
    windowTitle := ""
    try {
        processName := WinGetProcessName("ahk_id " . hwnd)
        windowTitle := WinGetTitle("ahk_id " . hwnd)
    } catch {
        return ""
    }

    if (Beacon_IsBeaconWindow(processName, windowTitle))
        return ""

    appType := Beacon_DetectAppShortcutType(processName, windowTitle)
    if (appType = "" || !Beacon_CommandIndex.Has(appType))
        return ""

    appCommands := Beacon_CommandIndex[appType]
    return appCommands.Has(normalizedCommand) ? appCommands[normalizedCommand] : ""
}

Beacon_SetPendingHeldShortcut(sendText, delayMs) {
    global Beacon_PendingHeldShortcutSend

    Beacon_PendingHeldShortcutSend := sendText
    SetTimer(Beacon_ReplayHeldShortcut, -delayMs)
}

Beacon_ClearPendingHeldShortcut() {
    global Beacon_PendingHeldShortcutSend

    Beacon_PendingHeldShortcutSend := ""
    try {
        SetTimer(Beacon_ReplayHeldShortcut, 0)
    } catch {
    }
}

Beacon_ReplayHeldShortcut() {
    global Beacon_PendingHeldShortcutSend

    sendText := Beacon_PendingHeldShortcutSend
    Beacon_ClearPendingHeldShortcut()

    if (sendText != "")
        Beacon_SendHeldShortcut(sendText)
}

Beacon_SendHeldShortcut(sendText) {
    global Beacon_ReplayingHeldShortcut

    Beacon_ReplayingHeldShortcut := true
    try {
        Send(sendText)
    } catch {
    }
    SetTimer(Beacon_ClearHeldShortcutReplayFlag, -250)
}

Beacon_ClearHeldShortcutReplayFlag() {
    global Beacon_ReplayingHeldShortcut

    Beacon_ReplayingHeldShortcut := false
}

Beacon_CommandToSendString(normalizedCommand) {
    parts := StrSplit(normalizedCommand, " + ")
    down := ""
    up := ""
    keyText := ""

    for part in parts {
        if (part = "Ctrl") {
            down .= "{Ctrl down}"
            up := "{Ctrl up}" . up
        } else if (part = "Alt") {
            down .= "{Alt down}"
            up := "{Alt up}" . up
        } else if (part = "Shift") {
            down .= "{Shift down}"
            up := "{Shift up}" . up
        } else if (part = "Windows") {
            down .= "{LWin down}"
            up := "{LWin up}" . up
        } else {
            keyText := Beacon_CommandKeyToSendKey(part)
        }
    }

    if (keyText = "")
        return ""

    return down . keyText . up
}

Beacon_CommandKeyToSendKey(key) {
    if (RegExMatch(key, "i)^[A-Z0-9]$"))
        return StrLower(key)
    if (RegExMatch(key, "i)^F([1-9]|1[0-2])$"))
        return "{" . key . "}"

    static sendKeys := Map(
        "Escape", "{Esc}",
        "Enter", "{Enter}",
        "Tab", "{Tab}",
        "Space", "{Space}",
        "Backspace", "{Backspace}",
        "Delete", "{Delete}",
        "Home", "{Home}",
        "End", "{End}",
        "Page Up", "{PgUp}",
        "Page Down", "{PgDn}",
        "Insert", "{Insert}",
        "AppsKey", "{AppsKey}",
        "Print Screen", "{PrintScreen}"
    )

    return sendKeys.Has(key) ? sendKeys[key] : ""
}

Beacon_EstimateAnnouncementDelay(text) {
    rate := Beacon_GetEffectiveAnnounceRate()
    clean := Beacon_CleanAnnouncementText(text)
    words := 1
    for word in StrSplit(clean, " ") {
        if (Trim(word) != "")
            words += 1
    }

    wpm := 175 + rate * 12
    if (wpm < 90)
        wpm := 90
    if (wpm > 320)
        wpm := 320

    delay := Round((words / wpm) * 60000) + 180
    if (delay < 550)
        delay := 550
    if (delay > 2600)
        delay := 2600
    return delay
}

Beacon_ListenAnnounce_KeyDown(ih, vk, sc) {
    global Beacon_LastAnnounceInputTick
    global Beacon_AnnounceCommandsTimingMode, Beacon_ReplayingHeldShortcut

    if (Beacon_ReplayingHeldShortcut)
        return

    Beacon_LastAnnounceInputTick := A_TickCount

    keyId := Format("{:02X}:{:03X}", vk, sc)
    if (ih.KeysDown.Has(keyId))
        return
    ih.KeysDown[keyId] := true

    keyName := GetKeyName(Format("vk{:02X}sc{:03X}", vk, sc))
    if (Beacon_IsControlKeyName(keyName)) {
        Beacon_StopSpeech()
        return
    }

    if (Beacon_IsModifierKeyName(keyName))
        return

    command := Beacon_BuildCommandFromKey(keyName)
    if (command = "")
        return

    if (!Beacon_IsAutomaticAnnounceCommand(command))
        return

    if (Beacon_AnnounceCommandsTimingMode = "speak_first"
     && Beacon_IsHoldReplayEligibleCommand(command))
        return

    Beacon_AnnounceRecognizedCommand(command)
}

Beacon_ListenAnnounce_KeyUp(ih, vk, sc) {
    keyId := Format("{:02X}:{:03X}", vk, sc)
    try {
        if (ih.KeysDown.Has(keyId))
            ih.KeysDown.Delete(keyId)
    } catch {
    }
}

Beacon_IsModifierKeyName(keyName) {
    k := StrLower(keyName)
    return (k = "ctrl" || k = "control" || k = "lctrl" || k = "rctrl"
        || k = "alt" || k = "lalt" || k = "ralt"
        || k = "shift" || k = "lshift" || k = "rshift"
        || k = "lwin" || k = "rwin")
}

Beacon_IsControlKeyName(keyName) {
    k := StrLower(keyName)
    return (k = "ctrl" || k = "control" || k = "lctrl" || k = "rctrl")
}

Beacon_BuildCommandFromKey(keyName) {
    key := Beacon_NormalizeKeyName(keyName)
    if (key = "")
        return ""

    parts := []
    if (GetKeyState("LWin", "P") || GetKeyState("RWin", "P"))
        parts.Push("Windows")
    if (GetKeyState("Ctrl", "P"))
        parts.Push("Ctrl")
    if (GetKeyState("Alt", "P"))
        parts.Push("Alt")
    if (GetKeyState("Shift", "P"))
        parts.Push("Shift")

    parts.Push(key)
    return Beacon_JoinCommandParts(parts)
}

Beacon_NormalizeKeyName(keyName) {
    k := Trim(keyName)
    if (k = "")
        return ""

    lower := StrLower(k)
    static aliases := Map(
        "esc", "Escape",
        "escape", "Escape",
        "space", "Space",
        "spacebar", "Space",
        "space bar", "Space",
        "del", "Delete",
        "delete", "Delete",
        "pgup", "Page Up",
        "pageup", "Page Up",
        "page up", "Page Up",
        "pgdn", "Page Down",
        "pagedown", "Page Down",
        "page down", "Page Down",
        "up", "Up",
        "down", "Down",
        "left", "Left",
        "right", "Right",
        "enter", "Enter",
        "return", "Enter",
        "tab", "Tab",
        "backspace", "Backspace",
        "home", "Home",
        "end", "End",
        "appskey", "AppsKey",
        "apps key", "AppsKey",
        "printscreen", "Print Screen",
        "print screen", "Print Screen",
        "prtscn", "Print Screen",
        "period", ".",
        "dot", ".",
        "comma", ",",
        "semicolon", ";",
        "plus", "+",
        "minus", "-",
        "backtick", "``",
        "grave", "``",
        "grave accent", "``",
        "tilde", "~"
    )

    if (aliases.Has(lower))
        return aliases[lower]

    if (RegExMatch(k, "i)^F([1-9]|1[0-2])$"))
        return StrUpper(k)

    if (RegExMatch(k, "i)^Numpad(.+)$", &m))
        return "Numpad" . m[1]

    if (StrLen(k) = 1) {
        if (RegExMatch(k, "i)^[a-z]$"))
            return StrUpper(k)
        return k
    }

    return k
}

Beacon_JoinCommandParts(parts) {
    out := ""
    for part in parts
        out .= (out != "" ? " + " : "") . part
    return out
}

Beacon_IsAutomaticAnnounceCommand(command) {
    parts := StrSplit(command, " + ")
    key := parts[parts.Length]

    if (parts.Length > 1)
        return true

    if (RegExMatch(key, "i)^F([1-9]|1[0-2])$"))
        return true

    if (RegExMatch(key, "i)^(Escape|Enter|Tab|Backspace|Delete|Home|End|Page Up|Page Down|Up|Down|Left|Right|AppsKey|Print Screen)$"))
        return true

    return false
}

Beacon_AnnounceRecognizedCommand(command) {
    global Beacon_CommandIndex, Beacon_GlobalCommandIndex

    normalized := Beacon_NormalizeShortcutCommand(command)
    if (normalized = "")
        return

    if (Beacon_GlobalCommandIndex.Has(normalized)) {
        if (!Beacon_ShouldSuppressAnnouncement(normalized))
            Beacon_RequestAnnouncement(Beacon_GlobalCommandIndex[normalized])
        return
    }

    hwnd := WinExist("A")
    if (!hwnd)
        return

    processName := ""
    windowTitle := ""
    try {
        processName := WinGetProcessName("ahk_id " . hwnd)
        windowTitle := WinGetTitle("ahk_id " . hwnd)
    } catch {
        return
    }

    if (Beacon_IsBeaconWindow(processName, windowTitle))
        return

    appType := Beacon_DetectAppShortcutType(processName, windowTitle)
    if (appType = "" || !Beacon_CommandIndex.Has(appType))
        return

    appCommands := Beacon_CommandIndex[appType]
    if (!appCommands.Has(normalized))
        return

    if (Beacon_ShouldSuppressAnnouncement(normalized))
        return

    Beacon_RequestAnnouncement(appCommands[normalized])
}

Beacon_ShouldSuppressAnnouncement(normalizedCommand) {
    global Beacon_LastAnnouncedCommand, Beacon_LastAnnouncedTick

    now := A_TickCount
    if (normalizedCommand = Beacon_LastAnnouncedCommand
     && now - Beacon_LastAnnouncedTick < 900)
        return true

    Beacon_LastAnnouncedCommand := normalizedCommand
    Beacon_LastAnnouncedTick := now
    return false
}

Beacon_IsBeaconWindow(processName, windowTitle) {
    proc := StrLower(processName)
    title := StrLower(windowTitle)

    if (proc = "beacon.exe")
        return true
    if (RegExMatch(proc, "i)^autohotkey(32|64)?(_uia)?\.exe$")
     && InStr(title, "beacon"))
        return true
    return false
}

Beacon_RequestAnnouncement(text) {
    global Beacon_PendingSpeechText, Beacon_PendingSpeechQueuedTick

    say := Beacon_CleanAnnouncementText(text)
    if (say = "")
        return

    if (Beacon_ShouldUseScreenReaderCourtesyDelay()) {
        Beacon_PendingSpeechText := say
        Beacon_PendingSpeechQueuedTick := A_TickCount
        SetTimer(Beacon_FlushPendingSpeech, -Beacon_GetScreenReaderCourtesyInitialDelay())
        return
    }

    Beacon_Speak(say)
}

Beacon_FlushPendingSpeech() {
    global Beacon_PendingSpeechText

    if (Beacon_PendingSpeechText = "")
        return

    if (GetKeyState("Ctrl", "P")) {
        Beacon_ClearPendingSpeech()
        return
    }

    if (Beacon_ShouldContinueScreenReaderCourtesyDelay()) {
        SetTimer(Beacon_FlushPendingSpeech, -140)
        return
    }

    say := Beacon_PendingSpeechText
    Beacon_ClearPendingSpeech()
    Beacon_Speak(say)
}

Beacon_ClearPendingSpeech() {
    global Beacon_PendingSpeechText, Beacon_PendingSpeechQueuedTick

    Beacon_PendingSpeechText := ""
    Beacon_PendingSpeechQueuedTick := 0
    try {
        SetTimer(Beacon_FlushPendingSpeech, 0)
    } catch {
    }
}

Beacon_ShouldUseScreenReaderCourtesyDelay() {
    return Beacon_IsScreenReaderRunningForSpeechCourtesy()
}

Beacon_ShouldContinueScreenReaderCourtesyDelay() {
    global Beacon_LastAnnounceInputTick, Beacon_PendingSpeechQueuedTick
    global Beacon_LastScreenReaderAudioActiveTick

    if (!Beacon_IsScreenReaderRunningForSpeechCourtesy())
        return false

    now := A_TickCount
    maxWait := Beacon_GetScreenReaderCourtesyMaxWait()
    if (Beacon_PendingSpeechQueuedTick > 0
     && now - Beacon_PendingSpeechQueuedTick > maxWait)
        return false

    if (Beacon_IsScreenReaderAudioActive()) {
        Beacon_LastScreenReaderAudioActiveTick := now
        return true
    }

    if (Beacon_LastScreenReaderAudioActiveTick > 0
     && now - Beacon_LastScreenReaderAudioActiveTick < Beacon_GetScreenReaderAudioQuietTail())
        return true

    if (now - Beacon_LastAnnounceInputTick < Beacon_GetScreenReaderAudioStartGrace())
        return true

    return (now - Beacon_LastAnnounceInputTick < Beacon_GetScreenReaderCourtesyQuietWindow())
}

Beacon_GetScreenReaderCourtesyInitialDelay() {
    if (Beacon_IsJawsRunningForSpeechRate())
        return 250
    if (Beacon_IsNvdaRunning())
        return 250
    if (Beacon_IsNarratorRunningForSpeechRate())
        return 250
    return 300
}

Beacon_GetScreenReaderCourtesyQuietWindow() {
    if (Beacon_IsJawsRunningForSpeechRate())
        return 1000
    if (Beacon_IsNvdaRunning())
        return 800
    if (Beacon_IsNarratorRunningForSpeechRate())
        return 800
    return 900
}

Beacon_GetScreenReaderCourtesyMaxWait() {
    if (Beacon_IsJawsRunningForSpeechRate())
        return 9000
    if (Beacon_IsNvdaRunning())
        return 6000
    if (Beacon_IsNarratorRunningForSpeechRate())
        return 6000
    return 6500
}

Beacon_GetScreenReaderAudioStartGrace() {
    if (Beacon_IsJawsRunningForSpeechRate())
        return 1200
    if (Beacon_IsNvdaRunning())
        return 550
    if (Beacon_IsNarratorRunningForSpeechRate())
        return 550
    return 650
}

Beacon_GetScreenReaderAudioQuietTail() {
    if (Beacon_IsJawsRunningForSpeechRate())
        return 500
    if (Beacon_IsNvdaRunning())
        return 350
    if (Beacon_IsNarratorRunningForSpeechRate())
        return 350
    return 450
}

Beacon_IsScreenReaderRunningForSpeechCourtesy() {
    return Beacon_IsNvdaRunning() || Beacon_IsJawsRunningForSpeechRate()
        || Beacon_IsNarratorRunningForSpeechRate()
        || ProcessExist("supernova.exe") || ProcessExist("snova.exe")
        || ProcessExist("dolsnova.exe") || ProcessExist("dolsupernova.exe")
}

Beacon_IsScreenReaderAudioActive() {
    static CLSID_MMDeviceEnumerator := "{BCDE0395-E52F-467C-8E3D-C4579291692E}"
    static IID_IMMDeviceEnumerator := "{A95664D2-9614-4F35-A746-DE8DB63617E6}"
    static IID_IAudioSessionManager2 := "{77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F}"
    static IID_IAudioSessionControl2 := "{BFB7FF88-7239-4FC9-8FA2-07C950BE9C6D}"
    static IID_IAudioMeterInformation := "{C02216F6-8C67-4B5B-9D00-D008E73E0064}"
    static CLSCTX_ALL := 23

    try {
        enumerator := ComObject(CLSID_MMDeviceEnumerator, IID_IMMDeviceEnumerator)
        pDevice := 0
        ComCall(4, enumerator, "int", 0, "int", 0, "ptr*", &pDevice)
        if (!pDevice)
            return false

        device := ComValue(13, pDevice)
        iidMgr := Beacon_GUIDBuffer(IID_IAudioSessionManager2)
        pMgr := 0
        ComCall(3, device, "ptr", iidMgr.Ptr, "uint", CLSCTX_ALL, "ptr", 0,
            "ptr*", &pMgr)
        if (!pMgr)
            return false

        mgr := ComValue(13, pMgr)
        pSessions := 0
        ComCall(5, mgr, "ptr*", &pSessions)
        if (!pSessions)
            return false

        sessions := ComValue(13, pSessions)
        count := 0
        ComCall(3, sessions, "int*", &count)
        loop count {
            pSession := 0
            ComCall(4, sessions, "int", A_Index - 1, "ptr*", &pSession)
            if (!pSession)
                continue

            session := ComValue(13, pSession)
            pid := 0
            try {
                ctrl2 := ComObjQuery(session, IID_IAudioSessionControl2)
                ComCall(14, ctrl2, "uint*", &pid)
            } catch {
                pid := 0
            }

            if (!Beacon_IsScreenReaderAudioProcessId(pid))
                continue

            peak := 0.0
            try {
                meter := ComObjQuery(session, IID_IAudioMeterInformation)
                ComCall(3, meter, "float*", &peak)
            } catch {
                peak := 0.0
            }

            if (peak > 0.0015)
                return true
        }
    } catch {
    }

    return false
}

Beacon_IsScreenReaderAudioProcessId(pid) {
    if (!pid)
        return false

    try {
        processName := ProcessGetName(pid)
    } catch {
        return false
    }

    return Beacon_IsScreenReaderAudioProcessName(processName)
}

Beacon_IsScreenReaderAudioProcessName(processName) {
    proc := StrLower(processName)

    static screenReaderAudioProcesses := Map(
        "jfw.exe", true,
        "jaw64.exe", true,
        "jfw64.exe", true,
        "fsatproxy.exe", true,
        "fssynth32.exe", true,
        "fssynth64.exe", true,
        "fssynth.exe", true,
        "nvda.exe", true,
        "nvda_nouiaccess.exe", true,
        "narrator.exe", true,
        "supernova.exe", true,
        "snova.exe", true,
        "dolsnova.exe", true,
        "dolsupernova.exe", true
    )

    if (screenReaderAudioProcesses.Has(proc))
        return true

    return (InStr(proc, "jaws") || InStr(proc, "vocalizer")
        || InStr(proc, "eloq") || InStr(proc, "freedomsci"))
}

Beacon_Speak(text) {
    say := Beacon_CleanAnnouncementText(text)
    if (say = "")
        return

    try {
        voice := Beacon_GetSpeechVoice()
        voice.Speak(say, 3)
    } catch {
        ToolTip(say)
        SetTimer(() => ToolTip(), -1300)
    }
}

Beacon_SpeakAndWait(text) {
    say := Beacon_CleanAnnouncementText(text)
    if (say = "")
        return

    try {
        voice := Beacon_GetSpeechVoice()
        voice.Speak(say, 3)
        timeoutMs := Beacon_EstimateAnnouncementDelay(say) + 1200
        if (timeoutMs < 900)
            timeoutMs := 900
        if (timeoutMs > 4500)
            timeoutMs := 4500
        deadline := A_TickCount + timeoutMs

        loop {
            done := false
            try {
                done := voice.WaitUntilDone(25)
            } catch {
                try {
                    done := (voice.Status.RunningState != 2)
                } catch {
                    done := true
                }
            }

            if (done)
                break

            if (A_TickCount > deadline) {
                try {
                    voice.Speak("", 3)
                } catch {
                }
                break
            }

            Sleep(10)
        }
    } catch {
        ToolTip(say)
        SetTimer(() => ToolTip(), -1300)
        Sleep(Beacon_EstimateAnnouncementDelay(say))
    }
}

Beacon_GetSpeechVoice(forceNew := false) {
    global Beacon_SpeechVoice, Beacon_SpeechVoiceCreatedTick

    if (forceNew || !IsObject(Beacon_SpeechVoice)
     || A_TickCount - Beacon_SpeechVoiceCreatedTick > 10000) {
        Beacon_SpeechVoice := ComObject("SAPI.SpVoice")
        Beacon_SpeechVoiceCreatedTick := A_TickCount
        Beacon_ApplySpeechAudioOutput(Beacon_SpeechVoice)
    }

    try {
        Beacon_SpeechVoice.Volume := 100
    } catch {
    }
    try {
        Beacon_SpeechVoice.Rate := Beacon_GetEffectiveAnnounceRate()
    } catch {
    }

    return Beacon_SpeechVoice
}

Beacon_ApplySpeechAudioOutput(voice) {
    global Beacon_AnnounceCommandsAudioOutputId

    if (Beacon_AnnounceCommandsAudioOutputId = "")
        return

    token := ""
    if (Beacon_AnnounceCommandsAudioOutputId = "__WINDOWS_DEFAULT__")
        token := Beacon_FindWindowsDefaultAudioOutputToken(voice)
    else if (Beacon_AnnounceCommandsAudioOutputId = "__PREFER_HEADSET__")
        token := Beacon_FindPreferredHeadsetAudioOutputToken(voice)
    else
        token := Beacon_FindSapiAudioOutputToken(voice, Beacon_AnnounceCommandsAudioOutputId)

    if (!IsObject(token))
        return

    try {
        voice.AudioOutput := token
    } catch {
    }
}

Beacon_FindWindowsDefaultAudioOutputToken(voice) {
    endpointId := Beacon_GetWindowsDefaultAudioEndpointId()
    endpointGuid := Beacon_ExtractAudioEndpointGuid(endpointId)
    if (endpointGuid = "")
        return ""

    try {
        tokens := voice.GetAudioOutputs()
        count := tokens.Count
        loop count {
            token := tokens.Item(A_Index - 1)
            if (InStr(StrLower(token.Id), endpointGuid))
                return token
        }
    } catch {
    }

    return ""
}

Beacon_GetWindowsDefaultAudioEndpointId() {
    static CLSID_MMDeviceEnumerator := "{BCDE0395-E52F-467C-8E3D-C4579291692E}"
    static IID_IMMDeviceEnumerator := "{A95664D2-9614-4F35-A746-DE8DB63617E6}"

    try {
        enumerator := ComObject(CLSID_MMDeviceEnumerator, IID_IMMDeviceEnumerator)
        pEnum := ComObjValue(enumerator)
        loop 3 {
            role := A_Index - 1
            endpointId := Beacon_GetWindowsDefaultAudioEndpointIdForRole(pEnum, role)
            if (endpointId != "")
                return endpointId
        }
    } catch {
    }

    return ""
}

Beacon_GetWindowsDefaultAudioEndpointIdForRole(pEnum, role) {
    pDevice := 0
    hr := DllCall(NumGet(NumGet(pEnum, "ptr") + 4 * A_PtrSize, "ptr"),
        "ptr", pEnum, "int", 0, "int", role, "ptr*", &pDevice, "uint")
    if (hr != 0 || !pDevice)
        return ""

    pId := 0
    endpointId := ""
    try {
        hr := DllCall(NumGet(NumGet(pDevice, "ptr") + 5 * A_PtrSize, "ptr"),
            "ptr", pDevice, "ptr*", &pId, "uint")
        if (hr = 0 && pId) {
            endpointId := StrGet(pId, "UTF-16")
            DllCall("ole32\CoTaskMemFree", "ptr", pId)
        }
    } catch {
    }

    try {
        ObjRelease(pDevice)
    } catch {
    }

    return endpointId
}

Beacon_ExtractAudioEndpointGuid(endpointId) {
    if (endpointId = "")
        return ""

    if (RegExMatch(endpointId, "i)\x7D\.\x7B([0-9a-f-]+)\x7D$", &match))
        return StrLower(match[1])

    if (RegExMatch(endpointId, "i)\x7B([0-9a-f-]+)\x7D$", &match))
        return StrLower(match[1])

    return ""
}

Beacon_GUIDBuffer(guidText) {
    buf := Buffer(16, 0)
    hr := DllCall("ole32\CLSIDFromString", "wstr", guidText, "ptr", buf, "uint")
    if (hr != 0)
        throw Error("Could not parse GUID: " . guidText)
    return buf
}

Beacon_FindSapiAudioOutputToken(voice, targetId) {
    if (targetId = "")
        return ""

    try {
        tokens := voice.GetAudioOutputs()
        count := tokens.Count
        loop count {
            token := tokens.Item(A_Index - 1)
            if (token.Id = targetId)
                return token
        }
    } catch {
    }

    return ""
}

Beacon_FindPreferredHeadsetAudioOutputToken(voice) {
    bestToken := ""
    bestScore := 0

    try {
        tokens := voice.GetAudioOutputs()
        count := tokens.Count
        loop count {
            token := tokens.Item(A_Index - 1)
            name := token.GetDescription()
            score := Beacon_ScoreHeadsetAudioOutputName(name)
            if (score > bestScore) {
                bestScore := score
                bestToken := token
            }
        }
    } catch {
    }

    return bestToken
}

Beacon_ScoreHeadsetAudioOutputName(name) {
    lower := StrLower(name)
    score := 0

    if (InStr(lower, "bluetooth"))
        score += 60
    if (InStr(lower, "headphones"))
        score += 50
    if (InStr(lower, "headset"))
        score += 50
    if (InStr(lower, "earbuds") || InStr(lower, "ear buds"))
        score += 45
    if (InStr(lower, "airpods") || InStr(lower, "air pods"))
        score += 45
    if (InStr(lower, "buds"))
        score += 35
    if (InStr(lower, "hands-free") || InStr(lower, "hands free"))
        score += 30

    if (InStr(lower, "tv") || InStr(lower, "hdmi") || InStr(lower, "nvidia"))
        score -= 40
    if (InStr(lower, "speaker") || InStr(lower, "speakers"))
        score -= 25
    if (InStr(lower, "cable") || InStr(lower, "virtual"))
        score -= 25

    return score
}

Beacon_GetSapiAudioOutputOptions() {
    outputs := []
    try {
        voice := ComObject("SAPI.SpVoice")
        tokens := voice.GetAudioOutputs()
        count := tokens.Count
        loop count {
            token := tokens.Item(A_Index - 1)
            outputs.Push(Map(
                "id", token.Id,
                "name", token.GetDescription()
            ))
        }
    } catch {
    }

    return outputs
}

Beacon_GetEffectiveAnnounceRate() {
    global Beacon_AnnounceCommandsRate

    detectedRate := Beacon_GetScreenReaderSpeechRate()
    if (detectedRate != "")
        return detectedRate

    return Beacon_AnnounceCommandsRate
}

Beacon_GetScreenReaderSpeechRate() {
    global Beacon_ScreenReaderSpeechRate
    global Beacon_ScreenReaderSpeechRateSource
    global Beacon_ScreenReaderSpeechRateCheckTick

    now := A_TickCount
    if (now - Beacon_ScreenReaderSpeechRateCheckTick < 5000)
        return Beacon_ScreenReaderSpeechRate

    Beacon_ScreenReaderSpeechRateCheckTick := now
    Beacon_ScreenReaderSpeechRate := ""
    Beacon_ScreenReaderSpeechRateSource := ""

    if (Beacon_IsNvdaRunning()) {
        rate := Beacon_ReadNvdaSpeechRate()
        if (rate != "") {
            Beacon_ScreenReaderSpeechRate := rate
            Beacon_ScreenReaderSpeechRateSource := "NVDA"
            return rate
        }
    }

    if (Beacon_IsJawsRunningForSpeechRate()) {
        rate := Beacon_ReadJawsSpeechRate()
        if (rate != "") {
            Beacon_ScreenReaderSpeechRate := rate
            Beacon_ScreenReaderSpeechRateSource := "JAWS"
            return rate
        }
    }

    if (Beacon_IsNarratorRunningForSpeechRate()) {
        rate := Beacon_ReadNarratorSpeechRate()
        if (rate != "") {
            Beacon_ScreenReaderSpeechRate := rate
            Beacon_ScreenReaderSpeechRateSource := "Narrator"
            return rate
        }
    }

    return ""
}

Beacon_IsNvdaRunning() {
    return ProcessExist("nvda.exe") || ProcessExist("nvda_noUIAccess.exe")
}

Beacon_IsJawsRunningForSpeechRate() {
    return ProcessExist("jfw.exe") || ProcessExist("jaw64.exe")
        || ProcessExist("jfw64.exe") || ProcessExist("fsATProxy.exe")
        || ProcessExist("fusion.exe") || ProcessExist("fsfusion.exe")
}

Beacon_IsNarratorRunningForSpeechRate() {
    return ProcessExist("narrator.exe")
}

Beacon_ReadNvdaSpeechRate() {
    appData := EnvGet("APPDATA")
    if (appData = "")
        return ""

    configPath := appData . "\nvda\nvda.ini"
    text := Beacon_ReadTextFile(configPath)
    if (text = "")
        return ""

    synth := Beacon_ReadNvdaSpeechValue(text, "synth")
    if (synth = "")
        return ""

    rateText := Beacon_ReadNvdaSpeechValue(text, "rate", synth)
    if (rateText = "")
        return ""

    rateBoostText := Beacon_ReadNvdaSpeechValue(text, "rateBoost", synth)
    return Beacon_MapNvdaRateToSapi(rateText, rateBoostText)
}

Beacon_ReadNvdaSpeechValue(text, keyName, synthName := "") {
    inSpeech := false
    inSynth := (synthName = "")
    targetKey := StrLower(keyName)
    targetSynth := StrLower(synthName)

    for rawLine in StrSplit(text, "`n", "`r") {
        line := Trim(rawLine)
        if (line = "" || SubStr(line, 1, 1) = "#" || SubStr(line, 1, 1) = ";")
            continue

        if (RegExMatch(line, "^\[\[(.+)\]\]$", &match)) {
            if (inSpeech)
                inSynth := (targetSynth != "" && StrLower(Trim(match[1])) = targetSynth)
            continue
        }

        if (RegExMatch(line, "^\[(.+)\]$", &match)) {
            inSpeech := (StrLower(Trim(match[1])) = "speech")
            inSynth := (synthName = "")
            continue
        }

        if (!inSpeech || !inSynth)
            continue

        eqPos := InStr(line, "=")
        if (!eqPos)
            continue

        currentKey := StrLower(Trim(SubStr(line, 1, eqPos - 1)))
        if (currentKey = targetKey)
            return Trim(SubStr(line, eqPos + 1))
    }

    return ""
}

Beacon_MapNvdaRateToSapi(rateText, rateBoostText := "") {
    rawRate := Beacon_ParseSpeechRateNumber(rateText)
    if (rawRate = "")
        return ""

    mapped := Round((rawRate - 50) / 5)
    if (StrLower(Trim(rateBoostText)) = "true")
        mapped += 2

    return Beacon_ClampDetectedSpeechRate(mapped)
}

Beacon_ReadJawsSpeechRate() {
    profilePath := Beacon_GetActiveJawsVoiceProfilePath()
    if (profilePath = "")
        return ""

    rawRate := Beacon_ReadJawsProfileRate(profilePath)
    if (rawRate = "")
        return ""

    synth := Beacon_ReadIniLikeValue(profilePath, "PrimarySynthesizer", "Options")
    return Beacon_MapJawsRateToSapi(rawRate, synth)
}

Beacon_GetActiveJawsVoiceProfilePath() {
    versions := Beacon_GetJawsVersionNames()
    for version in versions {
        appData := EnvGet("APPDATA")
        if (appData = "")
            continue

        configPath := appData . "\Freedom Scientific\JAWS\" . version
            . "\Settings\enu\DEFAULT.JCF"
        profileName := Beacon_ReadIniLikeValue(configPath, "ActiveVoiceProfileName", "Voice Profiles")
        if (profileName = "")
            continue

        profilePath := Beacon_FindJawsVoiceProfile(profileName, version)
        if (profilePath != "")
            return profilePath
    }

    return ""
}

Beacon_GetJawsVersionNames() {
    versionsText := ""
    seen := Map()
    appData := EnvGet("APPDATA")
    programData := EnvGet("ProgramData")

    if (appData != "")
        Beacon_AppendJawsVersions(appData . "\Freedom Scientific\JAWS", seen, &versionsText)
    if (programData != "")
        Beacon_AppendJawsVersions(programData . "\Freedom Scientific\JAWS", seen, &versionsText)

    versions := []
    versionsText := Trim(versionsText, "`r`n")
    if (versionsText = "")
        return versions

    sortedText := Sort(versionsText, "R")
    for version in StrSplit(sortedText, "`n", "`r") {
        version := Trim(version)
        if (version != "")
            versions.Push(version)
    }

    return versions
}

Beacon_AppendJawsVersions(rootPath, seen, &versionsText) {
    if (!DirExist(rootPath))
        return

    Loop Files, rootPath . "\*", "D" {
        version := A_LoopFileName
        if (!seen.Has(version)) {
            seen[version] := true
            versionsText .= version . "`n"
        }
    }
}

Beacon_FindJawsVoiceProfile(profileName, version) {
    roots := []
    appData := EnvGet("APPDATA")
    programData := EnvGet("ProgramData")

    if (appData != "")
        roots.Push(appData . "\Freedom Scientific\JAWS\" . version . "\Settings\VoiceProfiles")
    if (appData != "")
        roots.Push(appData . "\Freedom Scientific\JAWS\" . version . "\Settings\enu\VoiceProfiles")
    if (programData != "")
        roots.Push(programData . "\Freedom Scientific\JAWS\" . version . "\SETTINGS\VoiceProfiles")

    for rootPath in roots {
        if (!DirExist(rootPath))
            continue

        directPath := rootPath . "\" . profileName . ".VPF"
        if (FileExist(directPath))
            return directPath

        Loop Files, rootPath . "\*.vpf", "F" {
            fileStem := RegExReplace(A_LoopFileName, "i)\.vpf$")
            if (StrLower(fileStem) = StrLower(profileName))
                return A_LoopFileFullPath
        }
    }

    return ""
}

Beacon_ReadJawsProfileRate(profilePath) {
    language := Beacon_ReadIniLikeValue(profilePath, "PrimaryLanguage", "Options")
    sections := []

    if (language != "") {
        sections.Push(language . "-PCCursor")
        sections.Push(language . "-Global")
        sections.Push(language . "-Message")
    }

    sections.Push("-PCCursor")
    sections.Push("-Global")
    sections.Push("-Message")

    for sectionName in sections {
        rateText := Beacon_ReadIniLikeValue(profilePath, "Rate", sectionName)
        if (rateText != "")
            return rateText
    }

    return Beacon_ReadIniLikeValue(profilePath, "Rate")
}

Beacon_MapJawsRateToSapi(rateText, synthName := "") {
    rawRate := Beacon_ParseSpeechRateNumber(rateText)
    if (rawRate = "")
        return ""

    synth := StrLower(synthName)

    if (InStr(synth, "sapi") || InStr(synth, "msmobile") || InStr(synth, "microsoft")) {
        if (rawRate >= 0 && rawRate <= 20)
            return Beacon_ClampDetectedSpeechRate(rawRate - 10)
    }

    if (InStr(synth, "vocalizer") || InStr(synth, "dectalk")
     || InStr(synth, "dtsoft") || InStr(synth, "jsdt")) {
        return Beacon_ClampDetectedSpeechRate((rawRate - 175) / 15)
    }

    if (rawRate > 120)
        return Beacon_ClampDetectedSpeechRate((rawRate - 175) / 15)

    if (rawRate >= -10 && rawRate <= 10)
        return Beacon_ClampDetectedSpeechRate(rawRate)

    return Beacon_ClampDetectedSpeechRate((rawRate - 50) / 5)
}

Beacon_ReadNarratorSpeechRate() {
    try {
        speed := RegRead("HKEY_CURRENT_USER\Software\Microsoft\Narrator", "NeuralSpeechSpeed")
    } catch {
        return ""
    }

    rawSpeed := Beacon_ParseSpeechRateNumber(speed)
    if (rawSpeed = "")
        return ""

    return Beacon_ClampDetectedSpeechRate((rawSpeed - 15) / 2)
}

Beacon_ReadIniLikeValue(filePath, keyName, sectionName := "") {
    text := Beacon_ReadTextFile(filePath)
    if (text = "")
        return ""

    inWantedSection := (sectionName = "")
    targetSection := StrLower(sectionName)
    targetKey := StrLower(keyName)

    for rawLine in StrSplit(text, "`n", "`r") {
        line := Trim(rawLine)
        if (line = "" || SubStr(line, 1, 1) = ";" || SubStr(line, 1, 1) = "#")
            continue

        if (RegExMatch(line, "^\[(.+)\]$", &match)) {
            currentSection := StrLower(Trim(match[1]))
            inWantedSection := (sectionName = "" || currentSection = targetSection)
            continue
        }

        if (!inWantedSection)
            continue

        eqPos := InStr(line, "=")
        if (!eqPos)
            continue

        currentKey := StrLower(Trim(SubStr(line, 1, eqPos - 1)))
        if (currentKey = targetKey)
            return Trim(SubStr(line, eqPos + 1))
    }

    return ""
}

Beacon_ReadTextFile(filePath) {
    if (!FileExist(filePath))
        return ""

    try {
        return FileRead(filePath, "UTF-8")
    } catch {
        try {
            return FileRead(filePath)
        } catch {
            return ""
        }
    }
}

Beacon_ParseSpeechRateNumber(value) {
    cleanValue := Trim(String(value))
    cleanValue := StrReplace(cleanValue, "%")
    try {
        return Float(cleanValue)
    } catch {
        return ""
    }
}

Beacon_ClampDetectedSpeechRate(value) {
    try {
        n := Round(Float(value))
    } catch {
        return ""
    }

    if (n < -10)
        return -10
    if (n > 10)
        return 10
    return n
}

Beacon_ResetSpeechVoice() {
    global Beacon_SpeechVoice, Beacon_SpeechVoiceCreatedTick

    Beacon_SpeechVoice := ""
    Beacon_SpeechVoiceCreatedTick := 0
}

Beacon_StopSpeech() {
    global Beacon_SpeechVoice

    Beacon_ClearPendingSpeech()
    try {
        ToolTip()
    } catch {
    }

    if (!IsObject(Beacon_SpeechVoice))
        return

    try {
        Beacon_SpeechVoice.Speak("", 3)
    } catch {
    }
    try {
        Beacon_SpeechVoice.Skip("Sentence", 9999)
    } catch {
    }
}

Beacon_CleanAnnouncementText(text) {
    t := Trim(text)
    t := RegExReplace(t, "\s*\([^)]*(if enabled|optional|some builds|requires|Windows 11|Windows 10|macOS|web)[^)]*\)", "")
    t := RegExReplace(t, "\s{2,}", " ")
    if (StrLen(t) > 100)
        t := SubStr(t, 1, 100)
    return Trim(t, " `t`r`n.-")
}

Beacon_BuildCommandIndex() {
    global ShortcutGuides, Beacon_CommandIndex, Beacon_CommandIndexBuilt
    global Beacon_GlobalCommandIndex

    index := Map()
    for guideKey, guideData in ShortcutGuides {
        if (!guideData.Has("contentCallback"))
            continue
        cb := guideData["contentCallback"]
        if (Type(cb) != "Func" && Type(cb) != "BoundFunc")
            continue
        try {
            content := cb()
            rows := Beacon_ExtractCommandRows(content)
            if (rows.Count > 0)
                index[guideKey] := rows
        } catch {
        }
    }

    Beacon_CommandIndex := index
    Beacon_GlobalCommandIndex := Beacon_BuildGlobalCommandIndex()
    Beacon_CommandIndexBuilt := true
}

Beacon_BuildGlobalCommandIndex() {
    commands := Map()

    Beacon_AddGlobalCommand(commands, "Alt + Tab", "Switch between open apps")
    Beacon_AddGlobalCommand(commands, "Alt + Shift + Tab", "Switch backward between open apps")
    Beacon_AddGlobalCommand(commands, "Alt + Escape", "Cycle through open windows")
    Beacon_AddGlobalCommand(commands, "Alt + F4", "Close the active window")
    Beacon_AddGlobalCommand(commands, "Alt + Space", "Open the active window menu")
    Beacon_AddGlobalCommand(commands, "Ctrl + Shift + Escape", "Open Task Manager")
    Beacon_AddGlobalCommand(commands, "Windows + M", "Minimize all windows")
    Beacon_AddGlobalCommand(commands, "Windows + Shift + M", "Restore minimized windows")
    Beacon_AddGlobalCommand(commands, "Windows + D", "Show or hide the desktop")
    Beacon_AddGlobalCommand(commands, "Windows + E", "Open File Explorer")
    Beacon_AddGlobalCommand(commands, "Windows + L", "Lock your PC")
    Beacon_AddGlobalCommand(commands, "Windows + I", "Open Settings")
    Beacon_AddGlobalCommand(commands, "Windows + A", "Open Quick Settings")
    Beacon_AddGlobalCommand(commands, "Windows + S", "Open Search")
    Beacon_AddGlobalCommand(commands, "Windows + R", "Open Run")
    Beacon_AddGlobalCommand(commands, "Windows + V", "Open Clipboard history")
    Beacon_AddGlobalCommand(commands, "Windows + Tab", "Open Task View")
    Beacon_AddGlobalCommand(commands, "Windows + Shift + S", "Open screen snipping")
    Beacon_AddGlobalCommand(commands, "Windows + Period", "Open emoji panel")
    Beacon_AddGlobalCommand(commands, "Windows + `;", "Open emoji panel")
    Beacon_AddGlobalCommand(commands, "Windows + P", "Choose presentation display mode")
    Beacon_AddGlobalCommand(commands, "Windows + K", "Open Cast")
    Beacon_AddGlobalCommand(commands, "Windows + H", "Start voice typing")
    Beacon_AddGlobalCommand(commands, "Windows + U", "Open Accessibility settings")
    Beacon_AddGlobalCommand(commands, "Windows + X", "Open the Quick Link menu")
    Beacon_AddGlobalCommand(commands, "Windows + G", "Open Game Bar")
    Beacon_AddGlobalCommand(commands, "Windows + N", "Open Notification Center")
    Beacon_AddGlobalCommand(commands, "Windows + W", "Open Widgets")
    Beacon_AddGlobalCommand(commands, "Windows + Ctrl + D", "Create a new virtual desktop")
    Beacon_AddGlobalCommand(commands, "Windows + Ctrl + Left", "Switch to the virtual desktop on the left")
    Beacon_AddGlobalCommand(commands, "Windows + Ctrl + Right", "Switch to the virtual desktop on the right")
    Beacon_AddGlobalCommand(commands, "Windows + Ctrl + F4", "Close the current virtual desktop")
    Beacon_AddGlobalCommand(commands, "Windows + Up", "Maximize the window")
    Beacon_AddGlobalCommand(commands, "Windows + Down", "Restore or minimize the window")
    Beacon_AddGlobalCommand(commands, "Windows + Left", "Snap the window left")
    Beacon_AddGlobalCommand(commands, "Windows + Right", "Snap the window right")

    return commands
}

Beacon_AddGlobalCommand(commands, command, description) {
    normalized := Beacon_NormalizeShortcutCommand(command)
    if (normalized != "")
        commands[normalized] := description
}

Beacon_ExtractCommandRows(content) {
    rows := Map()
    lines := StrSplit(content, "`n", "`r")

    for line in lines {
        if (!RegExMatch(line, "^(\s*)(.{1,100}):\s{2,}(.+)$", &m)) {
            if (!RegExMatch(line, "^(\s*)(.{1,100}):\s*(.+)$", &m))
                continue
        }

        command := Trim(m[2])
        description := Trim(m[3])
        if (command = "" || description = "")
            continue
        if (!Beacon_LooksLikeShortcutCommand(command))
            continue
        if (!Beacon_CommandTextIsSafeForAutomaticListening(command))
            continue

        for variant in Beacon_GetCommandVariants(command) {
            normalized := Beacon_NormalizeShortcutCommand(variant)
            if (normalized = "")
                continue
            if (!Beacon_IsAutomaticAnnounceCommand(normalized))
                continue
            if (!rows.Has(normalized))
                rows[normalized] := description
        }
    }

    return rows
}

Beacon_CommandTextIsSafeForAutomaticListening(command) {
    c := Trim(command)

    if (RegExMatch(c, "i)\b(then|press and hold|hold|type|say|click|drag|scroll|mouse|touch)\b"))
        return false
    if (InStr(c, ","))
        return false
    if (InStr(c, " > "))
        return false
    if (InStr(c, " / ") && RegExMatch(c, "i)(Up/Down|Left/Right|On/Off)"))
        return false
    return true
}

Beacon_GetCommandVariants(command) {
    variants := []
    expanded := []

    if (InStr(command, " / ")) {
        for part in StrSplit(command, " / ")
            expanded.Push(Trim(part))
    } else {
        expanded.Push(Trim(command))
    }

    for item in expanded {
        if (RegExMatch(item, "i)\s+or\s+")) {
            markerText := RegExReplace(item, "i)\s+or\s+", "||")
            for part in StrSplit(markerText, "||")
                Beacon_PushNonEmpty(variants, part)
        } else {
            Beacon_PushNonEmpty(variants, item)
        }
    }

    return variants
}

Beacon_PushNonEmpty(arr, value) {
    v := Trim(value)
    if (v != "")
        arr.Push(v)
}

Beacon_NormalizeShortcutCommand(command) {
    c := Trim(command)
    if (c = "")
        return ""

    c := StrReplace(c, "Windows key", "Windows")
    c := StrReplace(c, "WinKey", "Windows")
    c := RegExReplace(c, "i)\bWin\b", "Windows")
    c := RegExReplace(c, "i)\bControl\b", "Ctrl")
    c := RegExReplace(c, "i)\bEsc\b", "Escape")
    c := RegExReplace(c, "i)\bSpacebar\b", "Space")
    c := RegExReplace(c, "i)\bSpace bar\b", "Space")
    c := RegExReplace(c, "i)\bDel\b", "Delete")
    c := RegExReplace(c, "i)\bPgUp\b", "Page Up")
    c := RegExReplace(c, "i)\bPgDn\b", "Page Down")
    c := RegExReplace(c, "\s*\([^)]*\)", "")
    c := RegExReplace(c, "\s+", " ")
    c := RegExReplace(c, "\s*\+\s*", " + ")
    c := Trim(c)

    parts := StrSplit(c, " + ")
    mods := Map("Windows", false, "Ctrl", false, "Alt", false, "Shift", false)
    key := ""

    for part in parts {
        p := Beacon_NormalizeCommandPart(part)
        if (p = "")
            continue
        if (mods.Has(p))
            mods[p] := true
        else if (key = "")
            key := p
        else
            return ""
    }

    if (key = "")
        return ""

    ordered := []
    modifierOrder := ["Windows", "Ctrl", "Alt", "Shift"]
    for mod in modifierOrder {
        if (mods[mod])
            ordered.Push(mod)
    }
    ordered.Push(key)
    return Beacon_JoinCommandParts(ordered)
}

Beacon_NormalizeCommandPart(part) {
    p := Trim(part)
    if (p = "")
        return ""

    lower := StrLower(p)
    static partAliases := Map(
        "windows", "Windows",
        "ctrl", "Ctrl",
        "control", "Ctrl",
        "alt", "Alt",
        "shift", "Shift",
        "escape", "Escape",
        "esc", "Escape",
        "space", "Space",
        "spacebar", "Space",
        "space bar", "Space",
        "delete", "Delete",
        "del", "Delete",
        "enter", "Enter",
        "return", "Enter",
        "tab", "Tab",
        "backspace", "Backspace",
        "home", "Home",
        "end", "End",
        "page up", "Page Up",
        "pageup", "Page Up",
        "pgup", "Page Up",
        "page down", "Page Down",
        "pagedown", "Page Down",
        "pgdn", "Page Down",
        "up", "Up",
        "down", "Down",
        "left", "Left",
        "right", "Right",
        "appskey", "AppsKey",
        "apps key", "AppsKey",
        "print screen", "Print Screen",
        "printscreen", "Print Screen",
        "prtscn", "Print Screen",
        "period", ".",
        "dot", ".",
        "comma", ",",
        "semicolon", ";",
        "plus", "+",
        "minus", "-",
        "backtick", "``",
        "grave", "``",
        "grave accent", "``",
        "tilde", "~"
    )

    if (partAliases.Has(lower))
        return partAliases[lower]
    if (RegExMatch(p, "i)^F([1-9]|1[0-2])$"))
        return StrUpper(p)
    if (RegExMatch(p, "i)^Numpad(.+)$", &m))
        return "Numpad" . m[1]
    if (StrLen(p) = 1 && RegExMatch(p, "i)^[a-z]$"))
        return StrUpper(p)
    return p
}

; -----------------------------------------------------------------------
; ShowSettingsDialog()
;   Displays the Beacon Settings window — startup toggle and hotkey editor.
; -----------------------------------------------------------------------
ShowSettingsDialog() {
    colors := Beacon_GetThemeColors()
    themeState := Beacon_GetWindowsThemeState()
    isDark := (themeState = "dark")
    useExplicitThemeColors := (themeState != "light")
    mutedTextColor := (themeState = "highcontrast") ? colors["textColor"] : 0x808080

    ; Dialog is 480 px wide; explicit margins keep controls from touching the edges
    W := 440   ; usable content width for controls

    SGui := Gui("+AlwaysOnTop", "Beacon Settings")
    SGui.BackColor  := colors["background"]
    SGui.MarginX    := 16
    SGui.MarginY    := 12

    if (isDark) {
        try {
            DllCall("dwmapi\DwmSetWindowAttribute",
                "Ptr", SGui.Hwnd, "UInt", 20, "Int*", 1, "UInt", 4)
        } catch {
        }
    }

    if (useExplicitThemeColors) {
        SGui.SetFont("s10 c" . Format("0x{:06X}", colors["textColor"]), "Segoe UI")
    } else {
        SGui.SetFont("s10", "Segoe UI")
    }

    ; ── Windows Startup ──────────────────────────────────────────────
    SGui.Add("Text", "w" . W . " xm", "Windows Startup")
    SGui.Add("Text", "w" . W . " h2 y+4 0x10")      ; divider line
    StartupChk := SGui.Add("Checkbox",
        "w" . W . " xm y+8 Checked" . (Beacon_IsInStartup() ? 1 : 0),
        "Start Beacon automatically with Windows")

    ; ── Custom Keyboard Shortcuts ─────────────────────────────────────
    SGui.Add("Text", "w" . W . " xm y+20", "Custom Keyboard Shortcuts  (optional)")
    SGui.Add("Text", "w" . W . " h2 y+4 0x10")      ; divider line

    SGui.Add("Text", "w" . W . " xm y+8 c" . Format("{:06X}", mutedTextColor),
        "Built-in hotkeys: Windows + Shift + H for menu, Windows + Shift + K for current app.")
    SGui.Add("Text", "w" . W . " xm y+4 c" . Format("{:06X}", mutedTextColor),
        "Legacy hotkeys: Backtick + 1 for menu, Backtick + 2 for current app.")
    SGui.Add("Text", "w" . W . " xm y+4 c" . Format("{:06X}", mutedTextColor),
        "Use the fields below to add an extra hotkey for either action.")

    SGui.Add("Text", "w" . W . " xm y+14", "Extra menu shortcut (optional):")
    MenuHkCtrl := SGui.Add("Hotkey", "w260 xm y+4", Beacon_MenuHotkey)

    SGui.Add("Text", "w" . W . " xm y+12", "Extra auto-detect shortcut (optional):")
    CtxHkCtrl := SGui.Add("Hotkey", "w260 xm y+4", Beacon_ContextHotkey)

    SGui.Add("Text", "w" . W . " xm y+8 c" . Format("{:06X}", mutedTextColor),
        "Click a box, then press a key combination.  Clear a box to remove it.")

    ; Announce Commands
    SGui.Add("Text", "w" . W . " xm y+20", "Announce Commands")
    SGui.Add("Text", "w" . W . " h2 y+4 0x10")      ; divider line
    AnnounceCommandsChk := SGui.Add("Checkbox",
        "w" . W . " xm y+8 Checked" . (Beacon_ListenAnnounceEnabled ? 1 : 0),
        "Announce recognized commands as I use applications")
    SGui.Add("Text", "w" . W . " xm y+4 c" . Format("{:06X}", mutedTextColor),
        "Press Ctrl to stop Beacon speech. Windows volume and app mixer settings still apply.")
    SGui.Add("Text", "w" . W . " xm y+10", "Audio output:")
    audioOutputOptions := ["Follow Windows default output"]
    audioOutputIds := ["__WINDOWS_DEFAULT__"]
    audioOutputChoose := 1
    audioOutputOptions.Push("Prefer headphones/headset/Bluetooth")
    audioOutputIds.Push("__PREFER_HEADSET__")
    if (Beacon_AnnounceCommandsAudioOutputId = "__PREFER_HEADSET__")
        audioOutputChoose := audioOutputOptions.Length
    audioOutputOptions.Push("Windows/SAPI default")
    audioOutputIds.Push("")
    if (Beacon_AnnounceCommandsAudioOutputId = "")
        audioOutputChoose := audioOutputOptions.Length
    for output in Beacon_GetSapiAudioOutputOptions() {
        audioOutputOptions.Push(output["name"])
        audioOutputIds.Push(output["id"])
        if (output["id"] = Beacon_AnnounceCommandsAudioOutputId)
            audioOutputChoose := audioOutputOptions.Length
    }
    AudioOutputDDL := SGui.Add("DropDownList",
        "w" . W . " xm y+4 Choose" . audioOutputChoose,
        audioOutputOptions)
    SGui.Add("Text", "w" . W . " xm y+4 c" . Format("{:06X}", mutedTextColor),
        "Automatic follows Windows Sound. Use headset or a specific device if needed.")
    SGui.Add("Text", "w" . W . " xm y+10", "Timing:")
    timingOptions := []
    timingOptions.Push("Wait for screen reader audio")
    timingOptions.Push("Speak before sending shortcut (experimental)")
    timingIds := []
    timingIds.Push("wait")
    timingIds.Push("speak_first")
    timingChoose := (Beacon_AnnounceCommandsTimingMode = "speak_first") ? 2 : 1
    TimingDDL := SGui.Add("DropDownList",
        "w" . W . " xm y+4 Choose" . timingChoose,
        timingOptions)
    SGui.Add("Text", "w" . W . " xm y+4 c" . Format("{:06X}", mutedTextColor),
        "Experimental mode holds recognized modifier shortcuts until Beacon finishes speaking.")
    SGui.Add("Text", "w" . W . " xm y+10", "Speaking rate:")
    rateOptions := []
    loop 21
        rateOptions.Push(String(A_Index - 11))
    RateDDL := SGui.Add("DropDownList",
        "w90 xm y+4 Choose" . (Beacon_AnnounceCommandsRate + 11),
        rateOptions)
    SGui.Add("Text", "w" . W . " xm y+4 c" . Format("{:06X}", mutedTextColor),
        "Beacon follows detected NVDA, JAWS, or Narrator rates when available.")
    SGui.Add("Text", "w" . W . " xm y+4 c" . Format("{:06X}", mutedTextColor),
        "If no screen reader rate is detected, this setting is used. 0 is normal.")

    ; ── Buttons ───────────────────────────────────────────────────────
    SaveBtn   := SGui.Add("Button", "w100 h30 xm y+16 Default", "Save")
    CancelBtn := SGui.Add("Button", "w100 h30 x+12 yp", "Cancel")

    VersionLbl := SGui.Add("Text", "w" . W . " xm y+12 c" . Format("{:06X}", mutedTextColor) . " Right", "Beacon  v" . Beacon_Version)

    if (useExplicitThemeColors) {
        SaveBtn.SetFont("s10 c" . Format("0x{:06X}", colors["buttonText"]))
        SaveBtn.Opt("+Background" . Format("0x{:06X}", colors["buttonBackground"]))
        CancelBtn.SetFont("s10 c" . Format("0x{:06X}", colors["buttonText"]))
        CancelBtn.Opt("+Background" . Format("0x{:06X}", colors["buttonBackground"]))
        if (isDark) {
            for ctrl in [StartupChk, MenuHkCtrl, CtxHkCtrl, AnnounceCommandsChk,
                         AudioOutputDDL, TimingDDL, RateDDL, SaveBtn, CancelBtn] {
                try {
                    DllCall("uxtheme\SetWindowTheme", "Ptr", ctrl.Hwnd,
                        "WStr", "DarkMode_Explorer", "Ptr", 0)
                } catch {
                }
            }
        }
    } else {
        SaveBtn.SetFont("s10 c" . Format("0x{:06X}", 0x000000))
        SaveBtn.Opt("+Background" . Format("0x{:06X}", 0xF5F5F5))
        CancelBtn.SetFont("s10 c" . Format("0x{:06X}", 0x000000))
        CancelBtn.Opt("+Background" . Format("0x{:06X}", 0xF5F5F5))
    }

    SGui.OnEvent("Close",  (*) => SGui.Destroy())
    SGui.OnEvent("Escape", (*) => SGui.Destroy())
    CancelBtn.OnEvent("Click", (*) => SGui.Destroy())

    DoSave(*) {
        global Beacon_MenuHotkey, Beacon_ContextHotkey, Beacon_ListenAnnounceEnabled
        global Beacon_AnnounceCommandsRate, Beacon_AnnounceCommandsAudioOutputId
        global Beacon_AnnounceCommandsTimingMode
        newMenu := MenuHkCtrl.Value
        newCtx  := CtxHkCtrl.Value
        newAnnounceCommands := AnnounceCommandsChk.Value
        newAudioOutputId := audioOutputIds[AudioOutputDDL.Value]
        newTimingMode := timingIds[TimingDDL.Value]
        newAnnounceRate := Beacon_ClampInteger(RateDDL.Text, -10, 10, 0)

        if (newMenu != "" && newCtx != "" && newMenu = newCtx) {
            MsgBox("The two hotkeys must be different.", "Beacon Settings", 48)
            return
        }

        Beacon_SetStartup(StartupChk.Value)

        Beacon_MenuHotkey    := newMenu
        Beacon_ContextHotkey := newCtx
        Beacon_ListenAnnounceEnabled := !!newAnnounceCommands
        Beacon_AnnounceCommandsAudioOutputId := newAudioOutputId
        Beacon_AnnounceCommandsTimingMode := newTimingMode
        Beacon_AnnounceCommandsRate := newAnnounceRate
        Beacon_SaveSettings(newMenu, newCtx, Beacon_ListenAnnounceEnabled,
            Beacon_AnnounceCommandsRate, Beacon_AnnounceCommandsAudioOutputId,
            Beacon_AnnounceCommandsTimingMode)
        Beacon_ApplyHotkeys()
        Beacon_ResetSpeechVoice()
        Beacon_ApplyListenAnnounce()

        SGui.Destroy()
        MsgBox("Settings saved successfully.", "Beacon Settings", 64)
    }
    SaveBtn.OnEvent("Click", DoSave)

    SGui.Show("AutoSize")
}

; =============================================================================
;                ENHANCED GUI DISPLAY SYSTEM (IMPROVED DARK MODE)
; =============================================================================

ShowShortcutGuide(shortcutType) {
    if (!ShortcutGuides.Has(shortcutType)) {
        MsgBox("Error: Shortcut type '" . shortcutType . "' not found in ShortcutGuides map.", "Configuration Error")
        return
    }

    restoreHwnd := Beacon_CaptureGuideReturnHwnd()

    guideData := ShortcutGuides[shortcutType]
    title := guideData.Get("title", "Keyboard Shortcuts")
    description := guideData.Get("description", "Keyboard shortcuts reference:")

    content := "Error: Content callback could not be executed."

    if (!guideData.Has("contentCallback")) {
        MsgBox("Error: 'contentCallback' key not found for shortcut type '" . shortcutType . "'.", "Configuration Error")
    } else {
        callbackFunc := guideData["contentCallback"]
        typeOfCallback := Type(callbackFunc)
        if (typeOfCallback == "Func" || typeOfCallback == "BoundFunc") {
             content := callbackFunc()
        } else {
            MsgBox("Error: contentCallback for '" . shortcutType . "' is not a callable function.", "Configuration Error")
            content := "Content callback for '" . shortcutType . "' is not a callable function."
        }
    }

    content := Beacon_FormatShortcutRows(content)

    ; Get current theme colors for dialog theming
    colors := Beacon_GetThemeColors()
    themeState := Beacon_GetWindowsThemeState()
    isDark := (themeState = "dark")
    useExplicitThemeColors := (themeState != "light")
    
    ; Create GUI with better sizing and theme-appropriate background
    ; +MinSize prevents the user from shrinking the window below a usable size;
    ; the OnEvent("Size", ...) handler below reflows child controls on resize.
    ShortcutGui := Gui("+Resize +MinSize480x360", title)
    ShortcutGui.MarginX := 10
    ShortcutGui.MarginY := 10
    ShortcutGui.BackColor := colors["background"]
    
    ; Apply dark mode to the window itself
    if (isDark) {
        try {
            DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", ShortcutGui.Hwnd, "UInt", 20, "Int*", 1, "UInt", 4)
        } catch {
            ; Ignore if not supported
        }
    }
    
    ; Set font with appropriate color and better size
    if (useExplicitThemeColors) {
        ShortcutGui.SetFont("s10 c" . Format("0x{:06X}", colors["textColor"]), "Consolas")
    } else {
        ShortcutGui.SetFont("s10", "Consolas")
    }
    
    ; Add description text with better styling
    DescText := ShortcutGui.Add("Text", "w620 Section", description)
    if (useExplicitThemeColors) {
        DescText.SetFont("s11 Bold c" . Format("0x{:06X}", colors["textColor"]))
    } else {
        DescText.SetFont("s11 Bold")
    }
    
    ; Parse sections for the filter dropdown
    fullContent := content
    sections    := Beacon_ParseSectionHeaders(content)

    ; Create text area (slightly shorter to leave room for filter row)
    textAreaOptions := "w620 h490 ReadOnly VScroll"
    if (useExplicitThemeColors) {
        textAreaOptions .= " Background" . Format("0x{:06X}", colors["editBackground"])
        textAreaOptions .= " c" . Format("0x{:06X}", colors["editText"])
    }
    TextArea := ShortcutGui.Add("Edit", textAreaOptions, content)

    ; ── Bottom row: filter label + DDL on the left, buttons on the right ──
    FilterLabel := ShortcutGui.Add("Text", "xm y+6 w50 h24 +0x200", "Filter")   ; 0x200 = SS_CENTERIMAGE (vertical center)
    FilterDDL := ShortcutGui.Add("DropDownList", "x+6 w210 Choose1 -TabStop", sections)
    ; -TabStop keeps DDL out of the keyboard Tab cycle initially; user
    ; can still click it.  Remove -TabStop below if Tab access is desired.
    FilterDDL.Opt("+TabStop")   ; actually DO include it in tab order — just don't give it initial focus

    SearchLabel := ShortcutGui.Add("Text", "x+10 w50 h24 +0x200", "Search:")
    searchOptions := "x+6 w150 h24 -WantReturn"
    if (useExplicitThemeColors) {
        searchOptions .= " Background" . Format("0x{:06X}", colors["editBackground"])
        searchOptions .= " c" . Format("0x{:06X}", colors["editText"])
    }
    SearchEdit := ShortcutGui.Add("Edit", searchOptions)

    ; Close button. Enter from Search is reserved for jumping to results.
    buttonOptions := "x+16 w100 h30 +0x8000"
    CloseButton := ShortcutGui.Add("Button", buttonOptions, "Close")

    ; Optional actionButton (e.g. "Visit Website" on Contact Us)
    ActionButton := ""   ; sentinel so the resize handler can test for it
    if (guideData.Has("actionButton")) {
        btn := guideData["actionButton"]
        ActionButton := ShortcutGui.Add("Button", "x+10 w130 h30 +0x8000", btn["label"])
        if (useExplicitThemeColors) {
            ActionButton.SetFont("s10 c" . Format("0x{:06X}", colors["buttonText"]))
            ActionButton.Opt("+Background" . Format("0x{:06X}", colors["buttonBackground"]))
            if (isDark) {
                try {
                    DllCall("uxtheme\SetWindowTheme", "Ptr", ActionButton.Hwnd, "WStr", "DarkMode_Explorer", "Ptr", 0)
                } catch {
                }
            }
        } else {
            ActionButton.SetFont("s10 c" . Format("0x{:06X}", 0x000000))
            ActionButton.Opt("+Background" . Format("0x{:06X}", 0xF5F5F5))
        }
        capturedURL := btn["url"]
        ActionButton.OnEvent("Click", (*) => Run(capturedURL))
    }

    ; Theme buttons and DDL
    if (useExplicitThemeColors) {
        if (isDark) {
            for ctrl in [CloseButton, FilterDDL, SearchEdit] {
                try {
                    DllCall("uxtheme\SetWindowTheme", "Ptr", ctrl.Hwnd, "WStr", "DarkMode_Explorer", "Ptr", 0)
                } catch {
                }
            }
            try {
                DllCall("uxtheme\SetWindowTheme", "Ptr", TextArea.Hwnd, "WStr", "DarkMode_Explorer", "Ptr", 0)
            } catch {
            }
        }
        CloseButton.SetFont("s10 c" . Format("0x{:06X}", colors["buttonText"]))
        CloseButton.Opt("+Background" . Format("0x{:06X}", colors["buttonBackground"]))
    } else {
        CloseButton.SetFont("s10 c" . Format("0x{:06X}", 0x000000))
        CloseButton.Opt("+Background" . Format("0x{:06X}", 0xF5F5F5))
    }

    ; Filter change — update Edit content; do NOT steal focus
    Beacon_UpdateShortcutFilters(*) {
        TextArea.Value := Beacon_ApplyContentFilters(fullContent, FilterDDL.Text, SearchEdit.Value)
        SendMessage(0x00B1, 0, 0, TextArea)
    }
    FilterDDL.OnEvent("Change", Beacon_UpdateShortcutFilters)
    SearchEdit.OnEvent("Change", Beacon_UpdateShortcutFilters)
    Beacon_RegisterSearchEnter(SearchEdit, TextArea, FilterDDL, fullContent)

    ; When TextArea regains focus (e.g. Shift+Tab from DDL, or screen reader
    ; landing on it), always clear any selection and place cursor at top.
    TextArea.OnEvent("Focus", (*) => SendMessage(0x00B1, 0, 0, TextArea))

    Beacon_CloseShortcutWindow(*) {
        Beacon_UnregisterSearchEnter(SearchEdit)
        ShortcutGui.Destroy()
        Beacon_RestoreFocusAfterGuide(restoreHwnd)
    }
    CloseButton.OnEvent("Click",   Beacon_CloseShortcutWindow)
    ShortcutGui.OnEvent("Escape",  Beacon_CloseShortcutWindow)
    ShortcutGui.OnEvent("Close",   Beacon_CloseShortcutWindow)

    ; ── Resize handler: reflow child controls when the window is resized ──
    ; Captures the controls created above via closure. Called whenever the
    ; user drags the window edges or maximizes/restores. Widths and positions
    ; are recomputed each time so the text area always fills the available
    ; horizontal space and the bottom row stays aligned at the bottom edge.
    margin    := 10
    rowHeight := 30                       ; bottom row height
    rowGap    := 6                        ; gap between text area and bottom row
    ; Optional ActionButton is only created when guideData has an actionButton;
    ; otherwise ActionButton stays as the empty-string sentinel set above.
    hasActionBtn := (ActionButton != "")
    ShortcutGui.OnEvent("Size", Beacon_ShortcutGui_Size)

    Beacon_ShortcutGui_Size(GuiObj, MinMax, W, H) {
        if (MinMax = -1)                  ; minimized -> nothing to do
            return
        clientW := W - margin * 2
        if (clientW < 100)
            clientW := 100

        ; Description text spans full client width at the top
        DescText.Move(margin, margin, clientW)

        ; Text area: starts below description, ends above the bottom row
        DescText.GetPos(, &dy, , &dh)
        taY := dy + dh + 6
        bottomRowY := H - margin - rowHeight
        taH := bottomRowY - rowGap - taY
        if (taH < 60)
            taH := 60
        TextArea.Move(margin, taY, clientW, taH)

        ; Bottom row: [Filter] [DDL] [Search] [ActionBtn?] [Close]
        labelW   := 50
        btnW     := 100
        actionW  := hasActionBtn ? 130 : 0
        searchLabelW := 50
        gapSmall := 6
        gapBig   := 16
        gapAct   := hasActionBtn ? 10 : 0

        ; Close button pinned to the right edge
        closeX := margin + clientW - btnW
        CloseButton.Move(closeX, bottomRowY, btnW, rowHeight)

        ; Optional action button sits just left of Close
        if (hasActionBtn) {
            actionX := closeX - gapAct - actionW
            ActionButton.Move(actionX, bottomRowY, actionW, rowHeight)
            rightEdge := actionX
        } else {
            rightEdge := closeX
        }

        ; Filter label on the left
        FilterLabel.Move(margin, bottomRowY + 3, labelW, 24)

        ; DropDownList and Search box share the space between label and right group
        ddlX := margin + labelW + gapSmall
        availableW := rightEdge - gapBig - ddlX
        ddlW := 170
        if (availableW < 350)
            ddlW := 130
        if (availableW < 260)
            ddlW := 90
        FilterDDL.Move(ddlX, bottomRowY + 3, ddlW)

        searchLabelX := ddlX + ddlW + gapSmall
        SearchLabel.Move(searchLabelX, bottomRowY + 3, searchLabelW, 24)

        searchX := searchLabelX + searchLabelW + gapSmall
        searchW := rightEdge - gapBig - searchX
        if (searchW < 80)
            searchW := 80
        SearchEdit.Move(searchX, bottomRowY + 3, searchW, 24)
    }

    ; Center the window on screen
    MonitorGetWorkArea(, &left, &top, &right, &bottom)
    dialogWidth  := 640
    dialogHeight := 620
    centerX := (right - left - dialogWidth)  // 2 + left
    centerY := (bottom - top - dialogHeight) // 2 + top

    ShortcutGui.Show("w" . dialogWidth . " h" . dialogHeight . " x" . centerX . " y" . centerY)

    ; Focus the text area (not the DDL) and clear any auto-selection
    TextArea.Focus()
    SendMessage(0x00B1, 0, 0, TextArea)
}

; =============================================================================
;                           SHORTCUT CONTENT FORMATTING
; =============================================================================
FormatHeader(titleText) {
    return "`n===============================================`n"
        . "      " . StrUpper(titleText) . "`n"
        . "===============================================`n`n"
}

Beacon_FormatShortcutRows(content) {
    formatted := ""
    lines := StrSplit(content, "`n", "`r")
    for index, line in lines {
        if (index > 1)
            formatted .= "`n"
        formatted .= Beacon_FormatShortcutRow(line)
    }
    return formatted
}

Beacon_FormatShortcutRow(line) {
    if (!RegExMatch(line, "^(\s*)(.{1,100}):\s{2,}(.+)$", &m)) {
        if (!RegExMatch(line, "^(\s*)(.{1,100}):\s*(.+)$", &m))
            return line
    }

    command := Trim(m[2])
    description := Trim(m[3])

    if (!Beacon_LooksLikeShortcutCommand(command))
        return line

    command := Beacon_AddShortcutKeyPronunciations(command)

    return m[1] . Beacon_PadShortcutDescription(description, 48) . command
}

Beacon_AddShortcutKeyPronunciations(command) {
    c := command

    c := Beacon_AddShortcutSymbolName(c, ".", "\.", "Period")
    c := Beacon_AddShortcutSymbolName(c, ",", ",", "Comma")
    c := Beacon_AddShortcutSymbolName(c, ";", ";", "Semicolon")
    c := Beacon_AddShortcutSymbolName(c, ":", ":", "Colon")
    c := Beacon_AddShortcutSymbolName(c, "'", "'", "Apostrophe")
    c := Beacon_AddShortcutSymbolName(c, Chr(34), "\x22", "Quotation mark")
    c := Beacon_AddShortcutSymbolName(c, Chr(96), "\x60", "Backtick")
    c := Beacon_AddShortcutSymbolName(c, "~", "~", "Tilde")
    c := Beacon_AddShortcutSymbolName(c, "?", "\?", "Question mark")
    c := Beacon_AddShortcutSymbolName(c, "!", "!", "Exclamation point")
    c := Beacon_AddShortcutSymbolName(c, "#", "#", "Number sign")
    c := Beacon_AddShortcutSymbolName(c, "[", "\[", "Left bracket")
    c := Beacon_AddShortcutSymbolName(c, "]", "\]", "Right bracket")
    c := Beacon_AddShortcutSymbolName(c, "<", "<", "Less than")
    c := Beacon_AddShortcutSymbolName(c, ">", ">", "Greater than")
    c := Beacon_AddShortcutSymbolName(c, "=", "=", "Equals sign")
    c := Beacon_AddShortcutSymbolName(c, "+", "\+", "Plus sign")
    c := Beacon_AddShortcutSymbolName(c, "-", "-", "Minus sign")
    c := Beacon_AddShortcutSymbolName(c, "*", "\*", "Asterisk")
    c := Beacon_AddShortcutSymbolName(c, "/", "/", "Slash")
    c := Beacon_AddShortcutSymbolName(c, "\", "\\", "Backslash")
    c := RegExReplace(c, ",\s+", ", then ")

    return c
}

Beacon_AddShortcutSymbolName(text, symbol, escapedSymbol, spokenName) {
    spoken := spokenName . " (" . symbol . ")"

    if (!RegExMatch(text, "i)^" . escapedSymbol . "\s*\(" . spokenName . "\)"))
        text := RegExReplace(text, "^" . escapedSymbol . "(?=$|\s|/|,)", spoken)
    text := RegExReplace(text, " \+ " . escapedSymbol . "(?!\s*\()", " + " . spoken)
    text := RegExReplace(text, " / " . escapedSymbol . "(?!\s*\()", " / " . spoken)
    text := RegExReplace(text, " or " . escapedSymbol . "(?!\s*\()", " or " . spoken)

    return text
}

Beacon_LooksLikeShortcutCommand(command) {
    c := Trim(command)

    if (RegExMatch(c, "i)^(Ctrl|Control|Alt|Shift|Windows key|Windows \+|Win \+|WinKey|Insert|Caps ?Lock|Narrator|NVDA|JAWS|MAGic Key|SN Key|Right Ctrl|Left Ctrl|Numpad|Num Lock|Num [0-9+\-*/.]|F[1-9][0-2]?|PrtScn|Print Screen|AppsKey)(\b|$|[^A-Za-z0-9_])"))
        return true
    if (RegExMatch(c, "i)^(Up|Down|Left|Right|Arrow|Home|End|Page Up|Page Down|Up/Down|Left/Right|Backspace|Delete|Esc|Escape|Enter|Tab|Space|Spacebar|Space bar|Any key|Mouse click|Touch|Click then drag|Scroll wheel|Drag title bar|Drag edge|Click X on OSK window|Microphone button)\b"))
        return true
    if (RegExMatch(c, "i)^(Say\s+|'[^']+'|\[[^\]]+\])"))
        return true
    if (RegExMatch(c, "i)^(Get|Set|Clear)-[A-Za-z]"))
        return true
    if (RegExMatch(c, "i)^(Press|Hold)\s+"))
        return true
    if (RegExMatch(c, "i)^(Click the|Click column|Middle-click|Double-click|Mouse selection)\b"))
        return true
    if (RegExMatch(c, "i)^Windows$"))
        return true
    if (RegExMatch(c, "i)^(Plus \(\+\)|Minus \(-\)|Num[+-]|Number \+ Enter|[+\-*/%#!\[\]]|[A-Z],|[A-Z]\s+or\b|[A-Z]\s+\+\s+[A-Z])"))
        return true
    if (RegExMatch(c, "i)^([A-Z0-9?]{1,3}|[A-Z][0-9]|[0-9]-[0-9]|F[1-9][0-2]?)(\s*/|\s*\(|$)"))
        return true

    return false
}

Beacon_PadShortcutDescription(description, width) {
    padding := width - StrLen(description)
    if (padding < 1)
        return description . ": "

    spaces := ""
    loop padding
        spaces .= " "
    return description . ":" . spaces
}

; -----------------------------------------------------------------------
; Beacon_ParseSectionHeaders(content)
;   Scans content for lines matching "-- Section Name --" and returns an
;   array starting with "All" followed by each unique section label.
;   Also captures top-level AT divider headers (==== style) as filter
;   targets in combined guide windows.
; -----------------------------------------------------------------------
Beacon_ParseSectionHeaders(content) {
    headers  := ["All"]
    seen     := Map()
    lines    := StrSplit(content, "`n")
    numLines := lines.Length
    i        := 1

    while (i <= numLines) {
        t := Trim(lines[i])

        ; Only match explicit "-- Section Name --" style headers.
        ; All-caps title lines produced by FormatHeader() are intentionally
        ; excluded here — those are document titles, not navigable sections.
        if RegExMatch(t, "^--\s+(.+?)\s+--$", &m) {
            label := m[1]
            if (!seen.Has(label)) {
                ; Peek ahead: require at least one real content line before
                ; the next section boundary (skipping blanks and === lines).
                hasContent := false
                j := i + 1
                while (j <= numLines) {
                    peek := Trim(lines[j])
                    if (peek = "") {               ; skip blank lines
                        j++
                        continue
                    }
                    if RegExMatch(peek, "^=+$") {  ; skip === divider borders
                        j++
                        continue
                    }
                    ; Stop at the next section header
                    if RegExMatch(peek, "^--\s+.+?\s+--$")
                        break
                    ; Anything else is real shortcut content
                    hasContent := true
                    break
                }
                if (hasContent) {
                    headers.Push(label)
                    seen[label] := true
                }
            }
        }
        i++
    }
    return headers
}

; -----------------------------------------------------------------------
; Beacon_FilterToSection(content, sectionName)
;   Returns the portion of content belonging to the named section.
;   "All" returns the full content unchanged.
;   For "-- ... --" sections: returns the header line + content until
;   the next "-- ... --" header or all-caps AT divider line (which
;   acts as a hard boundary between app and AT content in combined guides).
; -----------------------------------------------------------------------
Beacon_FilterToSection(content, sectionName) {
    if (sectionName = "All")
        return content

    lines    := StrSplit(content, "`n")
    result   := ""
    inTarget := false
    ; Determine which header style this is
    isDashSection := RegExMatch(sectionName, "^[^\-]") ; doesn't start with -

    for line in lines {
        t := Trim(line)

        ; Check if this line IS the target header (-- Section Name -- format only)
        isTarget := (t = "-- " . sectionName . " --")

        if (isTarget) {
            inTarget := true
            result   .= line . "`n"
            continue
        }

        if (inTarget) {
            ; Stop at next section boundary
            if RegExMatch(t, "^--\s+.+?\s+--$")
                break
            if (RegExMatch(t, "^[A-Z][A-Z\s\+]+[A-Z]$") && StrLen(t) > 6)
                break
            result .= line . "`n"
        }
    }
    return (result != "")
        ? result
        : "(No content found for section: " . sectionName . ")"
}

Beacon_ApplyContentFilters(content, sectionName, query) {
    sectionContent := Beacon_FilterToSection(content, sectionName)
    return Beacon_FilterContentBySearch(sectionContent, query)
}

Beacon_FilterContentBySearch(content, query) {
    q := StrLower(Trim(query))
    if (q = "")
        return content

    lines := StrSplit(content, "`n", "`r")
    result := ""
    currentSection := ""
    sectionIncluded := false
    matchCount := 0

    for line in lines {
        t := Trim(line)
        if RegExMatch(t, "^--\s+.+?\s+--$") {
            currentSection := line
            sectionIncluded := false
            continue
        }

        if (InStr(StrLower(line), q)) {
            if (currentSection != "" && !sectionIncluded) {
                result .= currentSection . "`n"
                sectionIncluded := true
            }
            result .= line . "`n"
            matchCount++
        }
    }

    return (matchCount > 0)
        ? result
        : "(No commands matched search: " . query . ")"
}

Beacon_RegisterSearchEnter(SearchEdit, TextArea, FilterDDL, fullContent) {
    global Beacon_SearchEnterTargets, Beacon_SearchEnterHandlerRegistered

    Beacon_SearchEnterTargets[SearchEdit.Hwnd] := Map(
        "search", SearchEdit,
        "text", TextArea,
        "filter", FilterDDL,
        "content", fullContent
    )

    if (!Beacon_SearchEnterHandlerRegistered) {
        OnMessage(0x0100, Beacon_SearchEnterMessageHandler) ; WM_KEYDOWN
        Beacon_SearchEnterHandlerRegistered := true
    }
}

Beacon_UnregisterSearchEnter(SearchEdit) {
    global Beacon_SearchEnterTargets
    try {
        if (Beacon_SearchEnterTargets.Has(SearchEdit.Hwnd))
            Beacon_SearchEnterTargets.Delete(SearchEdit.Hwnd)
    } catch {
    }
}

Beacon_SearchEnterMessageHandler(wParam, lParam, msg, hwnd) {
    global Beacon_SearchEnterTargets

    if (wParam != 13) ; Enter
        return

    focusHwnd := DllCall("GetFocus", "Ptr")
    targetHwnd := Beacon_SearchEnterTargets.Has(hwnd)
        ? hwnd
        : (Beacon_SearchEnterTargets.Has(focusHwnd) ? focusHwnd : 0)
    if (!targetHwnd)
        return

    target := Beacon_SearchEnterTargets[targetHwnd]
    searchCtrl := target["search"]
    textCtrl := target["text"]
    filterCtrl := target["filter"]
    fullContent := target["content"]

    textCtrl.Value := Beacon_ApplyContentFilters(fullContent, filterCtrl.Text, searchCtrl.Value)
    SendMessage(0x00B1, 0, 0, textCtrl)
    textCtrl.Focus()
    SendMessage(0x00B1, 0, 0, textCtrl)
    return 0
}

Beacon_CaptureGuideReturnHwnd() {
    try {
        return WinExist("A")
    } catch {
        return 0
    }
}

Beacon_RestoreFocusAfterGuide(hwnd) {
    if (!hwnd)
        return

    try {
        if (WinExist("ahk_id " . hwnd) && !WinActive("ahk_id " . hwnd))
            WinActivate("ahk_id " . hwnd)
    } catch {
    }
}

Beacon_WaitForBacktickRelease() {
    return
}

Beacon_SendLiteralBacktick(*) {
    SendText("``")
}

Beacon_ShowKeyboardMenuFromBacktick(*) {
    ShowKeyboardMenu()
}

Beacon_ShowContextualShortcutsFromBacktick(*) {
    ShowContextualShortcuts()
}

Beacon_IsAppStyleWebShortcut(appType) {
    static webTypes := Map(
        "GmailShortcut", true,
        "GoogleDocsShortcut", true,
        "GoogleSheetsShortcut", true,
        "GoogleSlidesShortcut", true,
        "GoogleMeetShortcut", true,
        "GoogleDriveShortcut", true,
        "GoogleCalendarShortcut", true,
        "GoogleChatShortcut", true,
        "YouTubeShortcut", true,
        "YouTubeMusicShortcut", true,
        "FacebookShortcut", true,
        "XShortcut", true,
        "LinkedInShortcut", true,
        "GitHubWebShortcut", true,
        "NotionShortcut", true,
        "DropboxShortcut", true,
        "FigmaShortcut", true,
        "TrelloShortcut", true,
        "CanvaShortcut", true,
        "MondayShortcut", true,
        "SharePointOnlineShortcut", true,
        "TeamsWebShortcut", true,
        "OneDriveWebShortcut", true,
        "WordOnlineShortcut", true,
        "ExcelOnlineShortcut", true,
        "PowerPointOnlineShortcut", true,
        "OutlookOnlineShortcut", true,
        "OneNoteOnlineShortcut", true
    )
    return webTypes.Has(appType)
}

Beacon_GetScreenReaderWebModeNote(appType, atList) {
    if (!Beacon_IsAppStyleWebShortcut(appType))
        return ""

    hasReaderModeAT := false
    for at in atList {
        if (at = "JAWS" || at = "NVDA" || at = "Narrator" || at = "SuperNova") {
            hasReaderModeAT := true
            break
        }
    }
    if (!hasReaderModeAT)
        return ""

    content := "Beacon can detect that a screen reader is running, but it cannot reliably query the current virtual cursor, browse mode, focus mode, or scan mode from outside that screen reader.`n"
    content .= "Use the screen-reader reading mode when you want heading, link, form, table, and landmark navigation. Use the website/application mode when you want the website's own single-letter shortcuts such as J, K, L, C, or S to act on posts or messages.`n`n"

    for at in atList {
        if (at = "JAWS") {
            content .= "JAWS: Insert + Z toggles the Virtual PC Cursor. Insert + 3 passes the next keystroke directly to the web page.`n"
        } else if (at = "NVDA") {
            content .= "NVDA: NVDA + Space toggles Browse Mode and Focus Mode. NVDA + Shift + Space passes the next keystroke directly to the web page.`n"
        } else if (at = "Narrator") {
            content .= "Narrator: Narrator key + Space toggles Scan Mode. Caps Lock and Insert are the default Narrator keys.`n"
        } else if (at = "SuperNova") {
            content .= "SuperNova: use Dolphin's browse/forms or pass-key command for web apps when single-letter website shortcuts are not reaching the page.`n"
        }
    }
    return content
}

; =============================================================================
;                      CONTENT FUNCTIONS (INCLUDE EXTERNAL FILE)
; =============================================================================


; =============================================================================
;                    CONTEXT-AWARE SHORTCUT DETECTION
; =============================================================================

Beacon_IsSupportedBrowserProcess(processName) {
    proc := StrLower(processName)
    return (proc = "chrome.exe"       || proc = "firefox.exe"
         || proc = "msedge.exe"       || proc = "microsoftedge.exe"
         || proc = "brave.exe"        || proc = "opera.exe"
         || proc = "operagx.exe"      || proc = "vivaldi.exe"
         || proc = "waterfox.exe"     || proc = "librewolf.exe"
         || proc = "floorp.exe"       || proc = "thorium.exe"
         || proc = "arc.exe"          || proc = "iexplore.exe")
}

Beacon_WaitForModifierRelease(timeoutMs := 700) {
    deadline := A_TickCount + timeoutMs
    modifierKeys := Array("LWin", "RWin", "LShift", "RShift", "LCtrl", "RCtrl", "LAlt", "RAlt")
    for keyName in modifierKeys {
        while (GetKeyState(keyName, "P") && A_TickCount < deadline)
            Sleep(10)
    }
}

Beacon_GetFocusedBrowserUrl(hwnd, processName) {
    if (!Beacon_IsSupportedBrowserProcess(processName))
        return ""
    if (!WinExist("ahk_id " . hwnd))
        return ""

    url := ""
    savedClipboard := ""
    hasSavedClipboard := false

    try {
        WinActivate("ahk_id " . hwnd)
        Beacon_WaitForModifierRelease()
        savedClipboard := ClipboardAll()
        hasSavedClipboard := true
        A_Clipboard := ""
        Send("^l")
        Sleep(80)
        Send("^c")
        if (ClipWait(0.5))
            url := Trim(A_Clipboard)
        Send("{Esc}")
    } catch {
        try {
            Send("{Esc}")
        } catch {
        }
    }

    if (hasSavedClipboard) {
        try {
            A_Clipboard := savedClipboard
        } catch {
        }
    }

    if (RegExMatch(url, "i)^(https?|ftp|file)://"))
        return StrLower(url)
    return ""
}

Beacon_TextHasAppTitleToken(text, appName) {
    return RegExMatch(text, "i)(^|[\s\-\|:])" . appName . "(\s*[\-\|:]|$)")
}

Beacon_DetectWebShortcutTypeFromText(rawText) {
    text := StrLower(rawText)
    if (text = "")
        return ""

    ; Google apps
    if (InStr(text, "music.youtube.com") || InStr(text, "youtube music"))
        return "YouTubeMusicShortcut"
    if (InStr(text, "youtube.com") || InStr(text, "youtu.be") || InStr(text, "youtube"))
        return "YouTubeShortcut"
    if (InStr(text, "docs.google.com/document") || InStr(text, "google docs"))
        return "GoogleDocsShortcut"
    if (InStr(text, "docs.google.com/spreadsheets") || InStr(text, "google sheets"))
        return "GoogleSheetsShortcut"
    if (InStr(text, "docs.google.com/presentation") || InStr(text, "google slides"))
        return "GoogleSlidesShortcut"
    if (InStr(text, "mail.google.com") || InStr(text, "gmail") || InStr(text, "google mail"))
        return "GmailShortcut"
    if (InStr(text, "meet.google.com") || InStr(text, "google meet"))
        return "GoogleMeetShortcut"
    if (InStr(text, "drive.google.com") || InStr(text, "google drive"))
        return "GoogleDriveShortcut"
    if (InStr(text, "calendar.google.com") || InStr(text, "google calendar"))
        return "GoogleCalendarShortcut"
    if (InStr(text, "chat.google.com") || InStr(text, "google chat"))
        return "GoogleChatShortcut"

    ; Social, design, and productivity sites
    if (InStr(text, "facebook.com") || InStr(text, "facebook"))
        return "FacebookShortcut"
    if (InStr(text, "x.com") || InStr(text, "twitter.com") || InStr(text, "twitter")
     || RegExMatch(text, "i)(^|[\s\-\|/])x(\s*[\-\|/]|$)"))
        return "XShortcut"
    if (InStr(text, "linkedin.com") || InStr(text, "linkedin"))
        return "LinkedInShortcut"
    if (InStr(text, "github.com") || InStr(text, "github"))
        return "GitHubWebShortcut"
    if (InStr(text, "notion.so") || InStr(text, "notion.site") || InStr(text, "notion"))
        return "NotionShortcut"
    if (InStr(text, "dropbox.com") || InStr(text, "dropbox"))
        return "DropboxShortcut"
    if (InStr(text, "figma.com") || InStr(text, "figjam") || InStr(text, "figma"))
        return "FigmaShortcut"
    if (InStr(text, "trello.com") || InStr(text, "trello"))
        return "TrelloShortcut"
    if (InStr(text, "canva.com") || InStr(text, "canva"))
        return "CanvaShortcut"
    if (InStr(text, "monday.com") || InStr(text, "monday work")
     || InStr(text, "monday crm") || InStr(text, "monday dev")
     || InStr(text, "workcanvas"))
        return "MondayShortcut"

    ; Microsoft 365 web apps. Office document hosts often expose only a
    ; document title plus "Word", "Excel", or "PowerPoint" in the browser title,
    ; so check those app title tokens before generic SharePoint.
    if (InStr(text, "teams.microsoft.com") || InStr(text, "microsoft teams"))
        return "TeamsWebShortcut"
    if (InStr(text, "outlook.office.com") || InStr(text, "outlook.live.com")
     || InStr(text, "mail.live.com") || InStr(text, "hotmail.com")
     || Beacon_TextHasAppTitleToken(text, "outlook"))
        return "OutlookOnlineShortcut"
    if (InStr(text, "onenote.officeapps.live.com") || InStr(text, "onenote.com")
     || InStr(text, "/launch/onenote") || Beacon_TextHasAppTitleToken(text, "onenote"))
        return "OneNoteOnlineShortcut"
    if (InStr(text, "word-edit.officeapps.live.com") || InStr(text, "word-view.officeapps.live.com")
     || InStr(text, "/launch/word") || InStr(text, "word online")
     || InStr(text, "word for the web") || Beacon_TextHasAppTitleToken(text, "word"))
        return "WordOnlineShortcut"
    if (InStr(text, "excel.officeapps.live.com") || InStr(text, "/launch/excel")
     || InStr(text, "excel online") || InStr(text, "excel for the web")
     || Beacon_TextHasAppTitleToken(text, "excel"))
        return "ExcelOnlineShortcut"
    if (InStr(text, "powerpoint.officeapps.live.com") || InStr(text, "/launch/powerpoint")
     || InStr(text, "powerpoint online") || InStr(text, "powerpoint for the web")
     || Beacon_TextHasAppTitleToken(text, "powerpoint"))
        return "PowerPointOnlineShortcut"
    if (InStr(text, "onedrive.live.com") || InStr(text, "onedrive.com")
     || InStr(text, "1drv.ms") || InStr(text, "onedrive"))
        return "OneDriveWebShortcut"
    if (InStr(text, "sharepoint.com") || InStr(text, "sharepoint"))
        return "SharePointOnlineShortcut"

    return ""
}

; ShowContextualShortcuts()
;   Detects the focused app AND any running AT tools, then displays the
;   matching shortcut guide.  If AT software is running, AT-specific
;   commands for the focused app are appended in a second section.
;   Falls back to the main menu when no guide is found.
;
;   Hotkey: Windows+Shift+K, legacy fallback Backtick+2
ShowContextualShortcuts() {
    ; Capture the active window BEFORE any GUI appears
    prevHwnd := WinExist("A")

    processName := ""
    windowTitle  := ""

    try {
        processName := WinGetProcessName("ahk_id " . prevHwnd)
        windowTitle  := WinGetTitle("ahk_id " . prevHwnd)
    } catch {
        ShowKeyboardMenu()
        return
    }

    focusedATType := Beacon_DetectFocusedAccessibilityShortcutType(processName, windowTitle)
    if (focusedATType != "") {
        ShowShortcutGuide(focusedATType)
        return
    }

    browserUrl := Beacon_GetFocusedBrowserUrl(prevHwnd, processName)
    appType := Beacon_DetectAppShortcutType(processName, windowTitle, browserUrl)
    atList  := Beacon_DetectRunningAT()

    ; Remove any AT tool whose own shortcut guide IS the focused app
    ; (e.g. if the user has the JAWS window in focus, don't overlay JAWS on itself)
    filteredAT := []
    for at in atList {
        atGuideKey := Beacon_GetATGuideKey(at)
        if (atGuideKey = "" || atGuideKey != appType)
            filteredAT.Push(at)
    }

    if (filteredAT.Length > 0) {
        ; AT detected — use the combined display
        ShowCombinedContextualGuide(appType, filteredAT)
    } else if (appType != "") {
        ; No AT running — show the app guide normally
        ShowShortcutGuide(appType)
    } else {
        ; No match at all — tooltip then main menu
        appDisplay := (processName != "") ? processName : "this application"
        ToolTip("No specific shortcuts found for: " . appDisplay . "`nOpening main menu...")
        SetTimer(() => ToolTip(), -1800)
        Sleep(300)
        ShowKeyboardMenu()
    }
}

; ShowCombinedContextualGuide(appType, atList)
;   Builds a single guide window that shows the focused app's shortcuts
;   in the first section and, for each running AT tool that has content
;   for this app, an AT-specific section below a divider.
ShowCombinedContextualGuide(appType, atList) {
    global ATAppCombos, ShortcutGuides

    restoreHwnd := Beacon_CaptureGuideReturnHwnd()

    ; ── Collect app content ───────────────────────────────────────────
    appTitle   := ""
    appContent := ""

    if (appType != "" && ShortcutGuides.Has(appType)) {
        gd := ShortcutGuides[appType]
        appTitle := gd.Get("title", "Application Shortcuts")
        cb := gd["contentCallback"]
        appContent := (Type(cb) = "Func" || Type(cb) = "BoundFunc") ? cb() : ""
    }

    ; ── Collect AT sections ───────────────────────────────────────────
    atSections := []
    for at in atList {
        if (!ATAppCombos.Has(at))
            continue
        atMap := ATAppCombos[at]
        key := atMap.Has(appType) ? appType : (atMap.Has("_general") ? "_general" : "")
        if (key = "")
            continue
        cb := atMap[key]
        if (Type(cb) != "Func" && Type(cb) != "BoundFunc")
            continue
        atLabel   := at . (appTitle != "" ? " + " . appTitle : " Commands")
        atContent := cb()
        atSections.Push(Map("label", atLabel, "content", atContent))
    }

    ; ── Decide what to show ───────────────────────────────────────────
    if (atSections.Length = 0) {
        ; AT is running but has no content for this app — fall back to app guide
        if (appType != "")
            ShowShortcutGuide(appType)
        else
            ShowKeyboardMenu()
        return
    }

    ; ── Build combined content string ─────────────────────────────────
    divider := "`n`n" . "================================================" . "`n"
    combinedContent := appContent
    modeNote := Beacon_GetScreenReaderWebModeNote(appType, atList)
    if (modeNote != "") {
        combinedContent .= divider
        combinedContent .= "  SCREEN READER MODE NOTE`n"
        combinedContent .= "================================================`n`n"
        combinedContent .= modeNote
    }
    for sec in atSections {
        combinedContent .= divider
        combinedContent .= "  " . StrUpper(sec["label"]) . "`n"
        combinedContent .= "================================================`n`n"
        combinedContent .= sec["content"]
    }

    ; ── Build window title ────────────────────────────────────────────
    combinedContent := Beacon_FormatShortcutRows(combinedContent)

    atNames := ""
    for at in atList {
        atNames .= (atNames != "" ? " + " : "") . at
    }
    winTitle := (appTitle != "" ? appTitle : "Application Shortcuts")
    if (atNames != "")
        winTitle .= "  [" . atNames . " detected]"

    description := appTitle != ""
        ? "Shortcuts for " . appTitle . " — " . atNames . " overlay commands shown below."
        : atNames . " accessibility commands for the current application."

    ; ── Render the guide window ───────────────────────────────────────
    colors := Beacon_GetThemeColors()
    themeState := Beacon_GetWindowsThemeState()
    isDark := (themeState = "dark")
    useExplicitThemeColors := (themeState != "light")

    ; +MinSize prevents the user from shrinking the window below a usable size;
    ; the OnEvent("Size", ...) handler below reflows child controls on resize.
    CGui := Gui("+Resize +MinSize480x360", winTitle)
    CGui.MarginX := 10
    CGui.MarginY := 10
    CGui.BackColor := colors["background"]

    if (isDark) {
        try {
            DllCall("dwmapi\DwmSetWindowAttribute",
                "Ptr", CGui.Hwnd, "UInt", 20, "Int*", 1, "UInt", 4)
        } catch {
        }
    }

    if (useExplicitThemeColors) {
        CGui.SetFont("s10 c" . Format("0x{:06X}", colors["textColor"]), "Consolas")
    } else {
        CGui.SetFont("s10", "Consolas")
    }

    DescText := CGui.Add("Text", "w620 Section", description)
    if (useExplicitThemeColors)
        DescText.SetFont("s11 Bold c" . Format("0x{:06X}", colors["textColor"]))
    else
        DescText.SetFont("s11 Bold")

    ; Parse sections for the filter dropdown
    fullCombined := combinedContent
    sections     := Beacon_ParseSectionHeaders(combinedContent)

    taOpts := "w620 h490 ReadOnly VScroll"
    if (useExplicitThemeColors) {
        taOpts .= " Background" . Format("0x{:06X}", colors["editBackground"])
        taOpts .= " c" . Format("0x{:06X}", colors["editText"])
    }
    TextArea := CGui.Add("Edit", taOpts, combinedContent)

    ; ── Bottom row: filter label + DDL left, Close right ──────────────
    FilterLabel := CGui.Add("Text", "xm y+6 w50 h24 +0x200", "Filter")
    FilterDDL := CGui.Add("DropDownList", "x+6 w210 Choose1", sections)
    SearchLabel := CGui.Add("Text", "x+10 w50 h24 +0x200", "Search:")
    cSearchOpts := "x+6 w150 h24 -WantReturn"
    if (useExplicitThemeColors) {
        cSearchOpts .= " Background" . Format("0x{:06X}", colors["editBackground"])
        cSearchOpts .= " c" . Format("0x{:06X}", colors["editText"])
    }
    SearchEdit := CGui.Add("Edit", cSearchOpts)
    CloseBtn  := CGui.Add("Button", "x+16 w100 h30 +0x8000", "Close")

    if (useExplicitThemeColors) {
        CloseBtn.SetFont("s10 c" . Format("0x{:06X}", colors["buttonText"]))
        CloseBtn.Opt("+Background" . Format("0x{:06X}", colors["buttonBackground"]))
        if (isDark) {
            for ctrl in [CloseBtn, FilterDDL, SearchEdit] {
                try {
                    DllCall("uxtheme\SetWindowTheme", "Ptr", ctrl.Hwnd,
                        "WStr", "DarkMode_Explorer", "Ptr", 0)
                } catch {
                }
            }
            try {
                DllCall("uxtheme\SetWindowTheme", "Ptr", TextArea.Hwnd,
                    "WStr", "DarkMode_Explorer", "Ptr", 0)
            } catch {
            }
        }
    } else {
        CloseBtn.SetFont("s10 c" . Format("0x{:06X}", 0x000000))
        CloseBtn.Opt("+Background" . Format("0x{:06X}", 0xF5F5F5))
    }

    Beacon_UpdateCombinedFilters(*) {
        TextArea.Value := Beacon_ApplyContentFilters(fullCombined, FilterDDL.Text, SearchEdit.Value)
        SendMessage(0x00B1, 0, 0, TextArea)
    }
    FilterDDL.OnEvent("Change", Beacon_UpdateCombinedFilters)
    SearchEdit.OnEvent("Change", Beacon_UpdateCombinedFilters)
    Beacon_RegisterSearchEnter(SearchEdit, TextArea, FilterDDL, fullCombined)

    ; When TextArea regains focus (e.g. Shift+Tab from DDL, or screen reader
    ; landing on it), always clear any selection and place cursor at top.
    TextArea.OnEvent("Focus", (*) => SendMessage(0x00B1, 0, 0, TextArea))

    Beacon_CloseCombinedWindow(*) {
        Beacon_UnregisterSearchEnter(SearchEdit)
        CGui.Destroy()
        Beacon_RestoreFocusAfterGuide(restoreHwnd)
    }
    CloseBtn.OnEvent("Click",  Beacon_CloseCombinedWindow)
    CGui.OnEvent("Escape",     Beacon_CloseCombinedWindow)
    CGui.OnEvent("Close",      Beacon_CloseCombinedWindow)

    ; ── Resize handler: reflow child controls on window resize ──────────
    ; Captures DescText, TextArea, FilterLabel, FilterDDL, CloseBtn via
    ; closure. Keeps the text area filling the available space and pins
    ; the bottom row to the bottom edge.
    cMargin    := 10
    cRowHeight := 30
    cRowGap    := 6
    CGui.OnEvent("Size", Beacon_CGui_Size)

    Beacon_CGui_Size(GuiObj, MinMax, W, H) {
        if (MinMax = -1)
            return
        clientW := W - cMargin * 2
        if (clientW < 100)
            clientW := 100

        DescText.Move(cMargin, cMargin, clientW)

        DescText.GetPos(, &dy, , &dh)
        taY := dy + dh + 6
        bottomRowY := H - cMargin - cRowHeight
        taH := bottomRowY - cRowGap - taY
        if (taH < 60)
            taH := 60
        TextArea.Move(cMargin, taY, clientW, taH)

        labelW   := 50
        btnW     := 100
        searchLabelW := 50
        gapSmall := 6
        gapBig   := 16

        closeX := cMargin + clientW - btnW
        CloseBtn.Move(closeX, bottomRowY, btnW, cRowHeight)

        FilterLabel.Move(cMargin, bottomRowY + 3, labelW, 24)

        ddlX := cMargin + labelW + gapSmall
        availableW := closeX - gapBig - ddlX
        ddlW := 170
        if (availableW < 350)
            ddlW := 130
        if (availableW < 260)
            ddlW := 90
        FilterDDL.Move(ddlX, bottomRowY + 3, ddlW)

        searchLabelX := ddlX + ddlW + gapSmall
        SearchLabel.Move(searchLabelX, bottomRowY + 3, searchLabelW, 24)

        searchX := searchLabelX + searchLabelW + gapSmall
        searchW := closeX - gapBig - searchX
        if (searchW < 80)
            searchW := 80
        SearchEdit.Move(searchX, bottomRowY + 3, searchW, 24)
    }

    CGui.Show("w660")
    ; Focus the text area (not the DDL) and clear any auto-selection
    TextArea.Focus()
    SendMessage(0x00B1, 0, 0, TextArea)
}

; Beacon_DetectAppShortcutType(processName, windowTitle, browserUrl)
;   Maps a process name (and browser window title/URL for web apps) to the
;   matching ShortcutGuides key.  Returns "" when no match is found.
;
;   To add a new app: drop an entry in the relevant block below.
Beacon_DetectAppShortcutType(processName, windowTitle, browserUrl := "") {
    proc  := StrLower(processName)
    title := StrLower(windowTitle)

    focusedATType := Beacon_DetectFocusedAccessibilityShortcutType(processName, windowTitle)
    if (focusedATType != "")
        return focusedATType

    ; ----------------------------------------------------------------
    ; Microsoft Office — Desktop
    ; ----------------------------------------------------------------
    if (proc = "winword.exe")
        return "WordShortcut"
    if (proc = "excel.exe")
        return "ExcelShortcut"
    if (proc = "powerpnt.exe")
        return "PowerPointShortcut"
    if (proc = "outlook.exe")
        return "OutlookShortcut"
    ; OneNote desktop maps to the Online guide (same shortcuts, same content)
    if (proc = "onenote.exe" || proc = "onenoteim.exe")
        return "OneNoteOnlineShortcut"
    ; Microsoft Access and Publisher (Office suite members)
    if (proc = "msaccess.exe")
        return "AccessShortcut"
    ; if (proc = "mspub.exe")       return "PublisherShortcut"   ; no guide yet

    ; ----------------------------------------------------------------
    ; LibreOffice / OpenOffice
    ; LibreOffice on Windows typically runs as soffice.exe for all apps;
    ; some installs have separate swriter.exe / scalc.exe launchers.
    ; Detect by process name first, then fall back to window title keywords.
    ; ----------------------------------------------------------------
    if (proc = "swriter.exe")
        return "LibreWriterShortcut"
    if (proc = "scalc.exe")
        return "LibreCalcShortcut"
    if (proc = "simpress.exe")
        return "LibreImpressShortcut"
    if (proc = "soffice.exe" || proc = "soffice.bin") {
        if (InStr(title, "writer") || InStr(title, ".odt") || InStr(title, ".doc"))
            return "LibreWriterShortcut"
        if (InStr(title, "calc") || InStr(title, ".ods") || InStr(title, ".xls"))
            return "LibreCalcShortcut"
        if (InStr(title, "impress") || InStr(title, ".odp") || InStr(title, ".ppt"))
            return "LibreImpressShortcut"
    }

    ; ----------------------------------------------------------------
    ; Audio / DAW
    ; ----------------------------------------------------------------
    if (proc = "reaper.exe" || proc = "reaper64.exe")
        return "ReaperShortcut"
    if (proc = "audacity.exe")
        return "AudacityShortcut"

    ; ----------------------------------------------------------------
    ; Video Production & Streaming
    ; ----------------------------------------------------------------
    if (proc = "obs64.exe" || proc = "obs32.exe" || proc = "obs.exe")
        return "OBSShortcut"
    ; DaVinci Resolve (free & Studio)
    if (proc = "resolve.exe" || proc = "davinciresolve.exe")
        return "DaVinciResolveShortcut"
    ; Adobe Premiere Pro (process name varies by version; cover common variants)
    if (InStr(proc, "premiere") || proc = "ppro.exe")
        return "PremierProShortcut"

    ; ----------------------------------------------------------------
    ; Media Players
    ; ----------------------------------------------------------------
    if (proc = "vlc.exe")
        return "VLCShortcut"
    if (proc = "wmplayer.exe")
        return "WindowsMediaPlayerShortcut"
    if (proc = "spotify.exe")
        return "SpotifyShortcut"
    if (proc = "foobar2000.exe")
        return "Foobar2000Shortcut"
    if (proc = "itunes.exe")
        return "ITunesShortcut"

    ; ----------------------------------------------------------------
    ; Code & Text Editors
    ; ----------------------------------------------------------------
    if (proc = "code.exe" || proc = "code - insiders.exe")
        return "VSCodeShortcut"
    ; Notepad++ (process name uses the + characters literally)
    if (proc = "notepad++.exe")
        return "NotepadPlusPlusShortcut"

    ; ----------------------------------------------------------------
    ; Windows System Utilities
    ; ----------------------------------------------------------------
    if (proc = "notepad.exe")
        return "NotepadShortcut"
    if (proc = "wordpad.exe")
        return "WordPadShortcut"
    if (proc = "mspaint.exe")
        return "PaintShortcut"
    if (proc = "snippingtool.exe" || proc = "screenclippinghost.exe" || proc = "screensketch.exe")
        return "SnippingToolShortcut"
    if (proc = "calc.exe" || proc = "calculator.exe")
        return "CalculatorShortcut"
    if (proc = "taskmgr.exe")
        return "TaskManagerShortcut"
    if (proc = "cmd.exe")
        return "CommandPromptShortcut"
    if (proc = "powershell.exe" || proc = "pwsh.exe")
        return "PowerShellShortcut"
    if (proc = "windowsterminal.exe" || proc = "wt.exe")
        return "WindowsTerminalShortcut"
    if (proc = "systemsettings.exe" || proc = "ms-settings.exe")
        return "WindowsSettingsShortcut"

    ; ----------------------------------------------------------------
    ; Windows Built-in Apps (UWP / Store)
    ; ----------------------------------------------------------------
    if (proc = "photos.exe" || InStr(proc, "microsoft.photos"))
        return "PhotosShortcut"
    if (proc = "hxmail.exe" || proc = "hxoutlook.exe" || proc = "windowsmail.exe")
        return "WindowsMailShortcut"
    if (proc = "hxcalendar.exe" || proc = "windowscalendar.exe")
        return "WindowsCalendarShortcut"
    if (proc = "windowsmaps.exe")
        return "WindowsMapsShortcut"
    if (proc = "stickynotes.exe" || InStr(proc, "stickynotes"))
        return "StickyNotesShortcut"
    if (InStr(proc, "soundrecorder") || InStr(proc, "voicerecorder") || proc = "windowsvoicerecorder.exe")
        return "VoiceRecorderShortcut"

    ; ----------------------------------------------------------------
    ; Accessibility Tools
    ; ----------------------------------------------------------------
    if (proc = "nvda.exe" || proc = "nvda_noUIAccess.exe")
        return "NVDAShortcut"
    if (proc = "jfw.exe" || proc = "jaw64.exe")
        return "JAWSShortcut"
    if (proc = "narrator.exe")
        return "NarratorShortcut"
    if (proc = "magnify.exe")
        return "MagnifierShortcut"
    if (proc = "zoomtext.exe" || proc = "ztvideo.exe" || proc = "ztangelia.exe")
        return "ZoomTextShortcut"
    if (proc = "voiceaccess.exe")
        return "VoiceAccessShortcut"
    if (proc = "natspeak.exe" || proc = "dragon.exe" || proc = "dragonbar.exe" || proc = "dns.exe")
        return "DragonShortcut"
    if (proc = "kesi1000.exe" || proc = "k1000.exe" || proc = "kurzweil1000.exe")
        return "Kurzweil1000Shortcut"
    if (proc = "k3w.exe" || proc = "k3000.exe" || proc = "kesi3000.exe")
        return "Kurzweil3000Shortcut"
    if (proc = "ipevovisualizer.exe" || proc = "visualizer.exe" || proc = "ipevo.exe")
        return "IPEVOVisualizerShortcut"
    ; Read&Write by Texthelp
    if (proc = "readandwrite.exe" || proc = "readandwriteforwindows.exe" || proc = "readwrite.exe")
        return "ReadAndWriteShortcut"
    ; MAGic by Freedom Scientific
    if (proc = "magic.exe" || proc = "magic64.exe" || proc = "fsmagic.exe")
        return "MAGicShortcut"
    ; Dolphin SuperNova
    if (proc = "supernova.exe" || proc = "snova.exe" || proc = "dolsnova.exe")
        return "SuperNovaShortcut"
    ; Windows On-Screen Keyboard
    if (proc = "osk.exe")
        return "OSKShortcut"
    ; Windows Speech Recognition (sapisvr.exe = speech recognition engine; speechuxwiz.exe = UI)
    if (proc = "speechuxwiz.exe" || proc = "sapisvr.exe" || proc = "wsrec.exe")
        return "WindowsSpeechRecognitionShortcut"
    ; NaturalReader
    if (InStr(proc, "naturalreader") || proc = "nr.exe")
        return "NaturalReaderShortcut"

    ; ----------------------------------------------------------------
    ; Communication & Collaboration
    ; ----------------------------------------------------------------
    if (proc = "slack.exe")
        return "SlackShortcut"
    ; Discord ships three channels: stable, PTB (public test), Canary
    if (proc = "discord.exe" || proc = "discordptb.exe" || proc = "discordcanary.exe")
        return "DiscordShortcut"

    ; ----------------------------------------------------------------
    ; Conferencing
    ; ----------------------------------------------------------------
    if (InStr(proc, "zoom") && !InStr(proc, "zoomit"))
        return "ZoomShortcut"
    ; Teams: classic (teams.exe), new Teams (ms-teams.exe / msteams.exe)
    if ((proc = "teams.exe" || proc = "ms-teams.exe" || proc = "msteams.exe")
     && !InStr(proc, "steam"))
        return "TeamsShortcut"

    ; ----------------------------------------------------------------
    ; Creative Applications
    ; ----------------------------------------------------------------
    if (proc = "photoshop.exe" || proc = "photoshop (beta).exe")
        return "PhotoshopShortcut"

    ; ----------------------------------------------------------------
    ; File Utilities / Archive Managers
    ; ----------------------------------------------------------------
    ; 7-Zip File Manager (7zFM.exe) — the GUI front-end
    if (proc = "7zfm.exe")
        return "SevenZipShortcut"
    if (proc = "winrar.exe")
        return "WinRARShortcut"

    ; ----------------------------------------------------------------
    ; PDF
    ; ----------------------------------------------------------------
    if (proc = "acrord32.exe" || proc = "acrord64.exe" || proc = "acrobat.exe" || proc = "acrobatdc.exe")
        return "AdobeReaderShortcut"

    ; ----------------------------------------------------------------
    ; File Explorer
    ; explorer.exe can also be the desktop shell — exclude that case
    ; ----------------------------------------------------------------
    if (proc = "explorer.exe" && windowTitle != "" && !InStr(title, "program manager"))
        return "FileExplorerShortcut"

    ; ----------------------------------------------------------------
    ; Browser — detect web apps by window title first, then fall back
    ; to the generic browser guide.
    ; Add new browsers here as needed.
    ; ----------------------------------------------------------------
    isBrowser := Beacon_IsSupportedBrowserProcess(proc)

    if (isBrowser) {
        webType := Beacon_DetectWebShortcutTypeFromText(title . " " . browserUrl)
        if (webType != "")
            return webType

        ; Generic browser — no specific web app detected
        return "BrowserShortcut"
    }

    ; No match found
    return ""
}

#Include %A_ScriptDir%\content.ahk

; =============================================================================
;                           INITIALIZATION
; =============================================================================

; -----------------------------------------------------------------------
; Beacon_CleanupPendingFile()
;   If a previous compiled instance stored its path in PendingCleanup
;   (written just before launching this instance and calling ExitApp),
;   delete that file now.  Since the old process has already exited its
;   file lock is released.  Retries a few times to handle the rare case
;   where the OS hasn't finished releasing the handle yet.
;
;   Pass postMove := true when called after a /postmove launch so a tray
;   notification is shown confirming the move completed successfully.
; -----------------------------------------------------------------------
Beacon_CleanupPendingFile(postMove := false) {
    try {
        oldPath := RegRead("HKEY_CURRENT_USER\Software\Beacon", "PendingCleanup")
    } catch {
        return  ; No pending cleanup — nothing to do
    }

    ; Safety: never delete the currently running file
    if (oldPath = A_ScriptFullPath) {
        RegDelete("HKEY_CURRENT_USER\Software\Beacon", "PendingCleanup")
        return
    }

    ; Retry up to 10 times (up to ~1 second) in case the previous process
    ; hasn't fully released its handle yet
    loop 10 {
        try {
            if FileExist(oldPath)
                FileDelete(oldPath)
            RegDelete("HKEY_CURRENT_USER\Software\Beacon", "PendingCleanup")
            if (postMove)
                TrayTip("Beacon has been moved to:`n" . A_ScriptDir
                    . "`n`nIt will now start automatically with Windows.",
                    "Beacon Setup Complete")
            return
        } catch {
            Sleep(100)
        }
    }
    ; All retries failed — leave the key so the next launch can try again
}

; Use AutoHotkey's UIAccess runtime for the source version when available.
; This improves legacy hotkey reliability while focus is inside assistive
; technology windows that also run with UIAccess, such as JAWS.
Beacon_RelaunchWithUIAccessIfAvailable()

; Keep duplicate launches quiet without using AutoHotkey's built-in prompt.
Beacon_EnsureSingleInstance()

; Initialize shortcut guides data
InitializeShortcutGuides()

; Remove any old .exe left over from a previous "Start automatically" move.
; Pass postMove=true when this instance was launched by the old one as part
; of a self-relocate, so a tray tip confirms the move completed.
Beacon_CleanupPendingFile(Beacon_IsRelaunchFlagPresent("/postmove"))

; Register dark mode preference BEFORE building menus so every HMENU
; created by InitBeaconMenu() is born under the correct uxtheme context
Beacon_EnableDarkModeForApp()

; Build the native Menu() tree from MenuStructure
InitBeaconMenu()

; Build the AT+App combination content map
InitATAppCombos()

; Load saved hotkey preferences from Beacon_Settings.ini (creates defaults if absent)
Beacon_LoadSettings()

; Register the hotkeys dynamically so they can be changed via Settings
Beacon_ApplyHotkeys()

; Start or stop Announce Commands based on the saved setting
Beacon_ApplyListenAnnounce()

; Set up theme monitoring
Beacon_SetupThemeMonitoring()

; Register for theme change notifications
OnMessage(0x001A, (*) => Beacon_OnThemeChange()) ; WM_WININICHANGE

; Check for a newer version after a short delay so startup is not held up.
; The timer fires once (-5000 = one-shot after 5 seconds) and does nothing
; if the network is unavailable.
SetTimer(Beacon_CheckForUpdate, -5000)

; =============================================================================
;                           HOTKEYS
; =============================================================================
; These static hotkeys are ALWAYS active regardless of Settings.
; The Settings dialog lets you register one extra hotkey on top of these.
#+h::ShowKeyboardMenu()                     ; Windows+Shift+H shortcuts menu
#+k::ShowContextualShortcuts()              ; Windows+Shift+K auto-detect focused app
`::Beacon_SendLiteralBacktick()             ; pass backtick through when pressed alone
` & 1::Beacon_ShowKeyboardMenuFromBacktick()
` & 2::Beacon_ShowContextualShortcutsFromBacktick()
