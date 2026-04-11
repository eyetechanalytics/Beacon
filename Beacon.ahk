; =============================================================================
;                      Ultimate Keyboard Shortcuts System
;                      Version: 4.0.0 (Expanded Accessibility Coverage)
;                      (Added Read&Write, MAGic, SuperNova, OSK, WSR, NaturalReader)
;                      (Ease of Access features guide; reorganized Accessibility menu)
;                      (Version notes on all major content; LibreOffice full coverage)
;
; Description:
;   A comprehensive, modular system for displaying keyboard shortcuts for various
;   applications and features in Windows. Provides a centralized menu-based interface
;   for accessing a wide range of shortcut reference guides.
;
; Features:
;   - Menu-driven interface accessible via Apps Key + G
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
;   Press AppsKey + G to bring up the shortcuts menu
;   Press ` + 2 (backtick + 2) to auto-detect the focused app and show its shortcuts
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

; Function to get theme colors based on current Windows theme
Beacon_GetThemeColors() {
    isDark := Beacon_IsWindowsDarkMode()
    
    if (isDark) {
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

        isDark := Beacon_IsWindowsDarkMode()

        ; AllowDark (1) only works when the owner window has also been opted in
        ; via AllowDarkModeForWindow — a per-window call we can't make on AHK's
        ; internal TrackPopupMenuEx owner.  ForceDark (2) / ForceLight (3) bypass
        ; the per-window check entirely and set the rendering mode process-wide,
        ; which is the only reliable way to theme AHK native popup menus.
        preferredMode := isDark ? 2 : 3   ; 2 = ForceDark, 3 = ForceLight
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
        "title", "Welcome to the Ultimate Keyboard Shortcuts System",
        "description", "An overview of this script and how to use it:",
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
        ["Google Meet Shortcuts", "GoogleMeetShortcut"]
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
    ["File Explorer Shortcuts", "FileExplorerShortcut"],
    ["Adobe Reader Shortcuts", "AdobeReaderShortcut"],
    ["Zoom Shortcut commands", "ZoomShortcut"],
    ["Microsoft Teams Shortcut commands", "TeamsShortcut"],
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
Global CurrentTheme := Beacon_IsWindowsDarkMode()

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
    newTheme := Beacon_IsWindowsDarkMode()
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
    ; Refresh application theme when Windows theme changes
    Beacon_RefreshApplicationTheme()
}

; =============================================================================
;                    SETTINGS SYSTEM
; =============================================================================
;
;   Manages two persistent preferences stored in Beacon_Settings.ini:
;     1. Windows startup registration (HKCU Run registry key)
;     2. User-configurable hotkeys (registered dynamically via Hotkey())
;
;   Default hotkeys (overridden by saved settings):
;     Menu hotkey       : Ctrl+Alt+G  (^!g)
;     Contextual hotkey : Ctrl+Alt+C  (^!c)
; =============================================================================

; Current version — keep this in sync with the file name for compiled releases
; (e.g. Beacon.4.0.0.exe).  The update checker compares this against the value
; in Beacon_version.txt hosted on the download server.
Global Beacon_Version := "4.0.0"

; Path to the INI file sitting next to the script
Global Beacon_SettingsFile := A_ScriptDir . "\Beacon_Settings.ini"

; User-defined extra hotkeys (empty = none; the built-in static hotkeys always work)
Global Beacon_MenuHotkey    := ""
Global Beacon_ContextHotkey := ""

; Currently registered hotkey strings — tracked so they can be unregistered
; cleanly before registering replacements
Global Beacon_ActiveMenuHotkey    := ""
Global Beacon_ActiveContextHotkey := ""

; AT+App combo map — populated by InitATAppCombos() at startup
Global ATAppCombos := Map()

; -----------------------------------------------------------------------
; Beacon_DetectRunningAT()
;   Returns an array of shorthand keys for every accessibility tool that
;   is currently running as a process.  Possible values:
;   "JAWS", "NVDA", "Narrator", "ZoomText", "Magnifier",
;   "Dragon", "Kurzweil1000", "Kurzweil3000", "IPEVOVisualizer",
;   "ReadAndWrite", "MAGic", "SuperNova", "NaturalReader"
; -----------------------------------------------------------------------
Beacon_DetectRunningAT() {
    atList := []
    if (WinExist("ahk_exe jfw.exe") || WinExist("ahk_exe jaw64.exe"))
        atList.Push("JAWS")
    if (WinExist("ahk_exe nvda.exe") || WinExist("ahk_exe nvda_noUIAccess.exe"))
        atList.Push("NVDA")
    if (WinExist("ahk_exe narrator.exe"))
        atList.Push("Narrator")
    if (WinExist("ahk_exe zoomtext.exe") || WinExist("ahk_exe ztvideo.exe")
     || WinExist("ahk_exe ztangelia.exe") || WinExist("ahk_exe zoomdisplay.exe"))
        atList.Push("ZoomText")
    if (WinExist("ahk_exe magnify.exe"))
        atList.Push("Magnifier")
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
     || WinExist("ahk_exe dolsnova.exe"))
        atList.Push("SuperNova")
    ; NaturalReader (text-to-speech)
    if (WinExist("ahk_exe NaturalReader.exe") || WinExist("ahk_exe NaturalReader16.exe")
     || WinExist("ahk_exe nr.exe"))
        atList.Push("NaturalReader")
    return atList
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
; Beacon_CheckForUpdate()
;   Fetches Beacon_version.txt from the download server and compares it
;   to Beacon_Version.  If a newer version is available, offers to open
;   the download page in the user's default browser.
;
;   The version manifest is a plain-text file containing only the latest
;   version string, e.g.:  4.0.1
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
        result := MsgBox(
            "A new version of Beacon is available!`n`n"
            . "Your version:   " . Beacon_Version . "`n"
            . "Latest version: " . latestVersion . "`n`n"
            . "Would you like to download the update?",
            "Beacon Update Available", 4|64|4096)   ; Yes/No, info icon, always on top

        if (result = "Yes")
            Run(downloadURL)   ; Opens in default browser / triggers download

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
                  "YouTubeShortcut","YouTubeMusicShortcut","SharePointOnlineShortcut",
                  "TeamsOnlineShortcut","TeamShortcut"] {
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
                  "YouTubeShortcut","YouTubeMusicShortcut","SharePointOnlineShortcut",
                  "TeamsOnlineShortcut","TeamShortcut"] {
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
                  "YouTubeShortcut","YouTubeMusicShortcut","SharePointOnlineShortcut",
                  "TeamsOnlineShortcut","TeamShortcut"] {
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
                  "GoogleSlidesShortcut","GmailShortcut"] {
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
    for bType in ["BrowserShortcut","GoogleDocsShortcut","GmailShortcut"] {
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
                : ('"' . A_AhkPath . '" "' . destFile . '"')
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
                : ('"' . A_AhkPath . '" "' . destFile . '"')
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
    global Beacon_MenuHotkey, Beacon_ContextHotkey, Beacon_SettingsFile
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
}

; -----------------------------------------------------------------------
; Beacon_SaveSettings(menuHk, contextHk)
;   Writes hotkey preferences to Beacon_Settings.ini.
; -----------------------------------------------------------------------
Beacon_SaveSettings(menuHk, contextHk) {
    global Beacon_SettingsFile
    try {
        IniWrite(menuHk,    Beacon_SettingsFile, "Hotkeys", "MenuHotkey")
        IniWrite(contextHk, Beacon_SettingsFile, "Hotkeys", "ContextualHotkey")
    } catch {
    }
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
; ShowSettingsDialog()
;   Displays the Beacon Settings window — startup toggle and hotkey editor.
; -----------------------------------------------------------------------
ShowSettingsDialog() {
    colors := Beacon_GetThemeColors()
    isDark  := Beacon_IsWindowsDarkMode()

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

    SGui.Add("Text", "w" . W . " xm y+8 c808080",
        "Built-in hotkeys: Backtick + 1  (menu)  and  Backtick + 2  (auto-detect).")
    SGui.Add("Text", "w" . W . " xm y+4 c808080",
        "Use the fields below to add an extra hotkey for either action.")

    SGui.Add("Text", "w" . W . " xm y+14", "Extra menu shortcut (optional):")
    MenuHkCtrl := SGui.Add("Hotkey", "w260 xm y+4", Beacon_MenuHotkey)

    SGui.Add("Text", "w" . W . " xm y+12", "Extra auto-detect shortcut (optional):")
    CtxHkCtrl := SGui.Add("Hotkey", "w260 xm y+4", Beacon_ContextHotkey)

    SGui.Add("Text", "w" . W . " xm y+8 c808080",
        "Click a box, then press a key combination.  Clear a box to remove it.")

    ; ── Buttons ───────────────────────────────────────────────────────
    SaveBtn   := SGui.Add("Button", "w100 h30 xm y+16 Default", "Save")
    CancelBtn := SGui.Add("Button", "w100 h30 x+12 yp", "Cancel")

    VersionLbl := SGui.Add("Text", "w" . W . " xm y+12 c808080 Right", "Beacon  v" . Beacon_Version)

    if (isDark) {
        SaveBtn.SetFont("s10 c" . Format("0x{:06X}", 0xFFFFFF))
        SaveBtn.Opt("+Background" . Format("0x{:06X}", 0x3A3A3A))
        CancelBtn.SetFont("s10 c" . Format("0x{:06X}", 0xFFFFFF))
        CancelBtn.Opt("+Background" . Format("0x{:06X}", 0x3A3A3A))
        for ctrl in [StartupChk, MenuHkCtrl, CtxHkCtrl, SaveBtn, CancelBtn] {
            try {
                DllCall("uxtheme\SetWindowTheme", "Ptr", ctrl.Hwnd,
                    "WStr", "DarkMode_Explorer", "Ptr", 0)
            } catch {
            }
        }
    }

    SGui.OnEvent("Close",  (*) => SGui.Destroy())
    SGui.OnEvent("Escape", (*) => SGui.Destroy())
    CancelBtn.OnEvent("Click", (*) => SGui.Destroy())

    DoSave(*) {
        global Beacon_MenuHotkey, Beacon_ContextHotkey
        newMenu := MenuHkCtrl.Value
        newCtx  := CtxHkCtrl.Value

        if (newMenu != "" && newCtx != "" && newMenu = newCtx) {
            MsgBox("The two hotkeys must be different.", "Beacon Settings", 48)
            return
        }

        Beacon_SetStartup(StartupChk.Value)

        Beacon_MenuHotkey    := newMenu
        Beacon_ContextHotkey := newCtx
        Beacon_SaveSettings(newMenu, newCtx)
        Beacon_ApplyHotkeys()

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

    ; Get current theme colors for dialog theming
    colors := Beacon_GetThemeColors()
    isDark := Beacon_IsWindowsDarkMode()
    
    ; Create GUI with better sizing and theme-appropriate background
    ShortcutGui := Gui("+Resize", title)
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
    if (isDark) {
        ShortcutGui.SetFont("s10 c" . Format("0x{:06X}", colors["textColor"]), "Consolas")
    } else {
        ShortcutGui.SetFont("s10", "Consolas")
    }
    
    ; Add description text with better styling
    DescText := ShortcutGui.Add("Text", "w620 Section", description)
    if (isDark) {
        DescText.SetFont("s11 Bold c" . Format("0x{:06X}", colors["textColor"]))
    } else {
        DescText.SetFont("s11 Bold")
    }
    
    ; Parse sections for the filter dropdown
    fullContent := content
    sections    := Beacon_ParseSectionHeaders(content)

    ; Create text area (slightly shorter to leave room for filter row)
    textAreaOptions := "w620 h490 ReadOnly VScroll"
    if (isDark) {
        textAreaOptions .= " Background" . Format("0x{:06X}", colors["editBackground"])
        textAreaOptions .= " c" . Format("0x{:06X}", colors["editText"])
    }
    TextArea := ShortcutGui.Add("Edit", textAreaOptions, content)

    ; ── Bottom row: filter label + DDL on the left, buttons on the right ──
    ShortcutGui.Add("Text", "xm y+6 w90 h24 +0x200", "Filter section:")   ; 0x200 = SS_CENTERIMAGE (vertical center)
    FilterDDL := ShortcutGui.Add("DropDownList", "x+6 w210 Choose1 -TabStop", sections)
    ; -TabStop keeps DDL out of the keyboard Tab cycle initially; user
    ; can still click it.  Remove -TabStop below if Tab access is desired.
    FilterDDL.Opt("+TabStop")   ; actually DO include it in tab order — just don't give it initial focus

    ; Close button (Default so Enter activates it)
    buttonOptions := "x+16 w100 h30 Default +0x8000"
    CloseButton := ShortcutGui.Add("Button", buttonOptions, "Close")

    ; Optional actionButton (e.g. "Visit Website" on Contact Us)
    if (guideData.Has("actionButton")) {
        btn := guideData["actionButton"]
        ActionButton := ShortcutGui.Add("Button", "x+10 w130 h30 +0x8000", btn["label"])
        if (isDark) {
            ActionButton.SetFont("s10 c" . Format("0x{:06X}", 0xFFFFFF))
            ActionButton.Opt("+Background" . Format("0x{:06X}", 0x3A3A3A))
            try {
                DllCall("uxtheme\SetWindowTheme", "Ptr", ActionButton.Hwnd, "WStr", "DarkMode_Explorer", "Ptr", 0)
            } catch {
            }
        } else {
            ActionButton.SetFont("s10 c" . Format("0x{:06X}", 0x000000))
            ActionButton.Opt("+Background" . Format("0x{:06X}", 0xF5F5F5))
        }
        capturedURL := btn["url"]
        ActionButton.OnEvent("Click", (*) => Run(capturedURL))
    }

    ; Theme buttons and DDL
    if (isDark) {
        for ctrl in [CloseButton, FilterDDL] {
            try {
                DllCall("uxtheme\SetWindowTheme", "Ptr", ctrl.Hwnd, "WStr", "DarkMode_Explorer", "Ptr", 0)
            } catch {
            }
        }
        CloseButton.SetFont("s10 c" . Format("0x{:06X}", 0xFFFFFF))
        CloseButton.Opt("+Background" . Format("0x{:06X}", 0x3A3A3A))
        try {
            DllCall("uxtheme\SetWindowTheme", "Ptr", TextArea.Hwnd, "WStr", "DarkMode_Explorer", "Ptr", 0)
        } catch {
        }
    } else {
        CloseButton.SetFont("s10 c" . Format("0x{:06X}", 0x000000))
        CloseButton.Opt("+Background" . Format("0x{:06X}", 0xF5F5F5))
    }

    ; Filter change — update Edit content; do NOT steal focus
    FilterDDL.OnEvent("Change", (*) => (
        TextArea.Value := Beacon_FilterToSection(fullContent, FilterDDL.Text),
        SendMessage(0x00B1, 0, 0, TextArea)
    ))

    ; When TextArea regains focus (e.g. Shift+Tab from DDL, or screen reader
    ; landing on it), always clear any selection and place cursor at top.
    TextArea.OnEvent("Focus", (*) => SendMessage(0x00B1, 0, 0, TextArea))

    CloseButton.OnEvent("Click",   (*) => ShortcutGui.Destroy())
    ShortcutGui.OnEvent("Escape",  (*) => ShortcutGui.Destroy())
    ShortcutGui.OnEvent("Close",   (*) => ShortcutGui.Destroy())

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

; =============================================================================
;                      CONTENT FUNCTIONS (INCLUDE EXTERNAL FILE)
; =============================================================================


; =============================================================================
;                    CONTEXT-AWARE SHORTCUT DETECTION
; =============================================================================

; ShowContextualShortcuts()
;   Detects the focused app AND any running AT tools, then displays the
;   matching shortcut guide.  If AT software is running, AT-specific
;   commands for the focused app are appended in a second section.
;   Falls back to the main menu when no guide is found.
;
;   Hotkey: ` + 2  (backtick + 2)
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

    appType := Beacon_DetectAppShortcutType(processName, windowTitle)
    atList  := Beacon_DetectRunningAT()

    ; Remove any AT tool whose own shortcut guide IS the focused app
    ; (e.g. if the user has the JAWS window in focus, don't overlay JAWS on itself)
    filteredAT := []
    for at in atList {
        atGuideKey := Map("JAWS","JAWSShortcut","NVDA","NVDAShortcut",
                          "Narrator","NarratorShortcut","ZoomText","ZoomTextShortcut",
                          "Magnifier","MagnifierShortcut")
        if (!atGuideKey.Has(at) || atGuideKey[at] != appType)
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
    for sec in atSections {
        combinedContent .= divider
        combinedContent .= "  " . StrUpper(sec["label"]) . "`n"
        combinedContent .= "================================================`n`n"
        combinedContent .= sec["content"]
    }

    ; ── Build window title ────────────────────────────────────────────
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
    isDark  := Beacon_IsWindowsDarkMode()

    CGui := Gui("+Resize", winTitle)
    CGui.BackColor := colors["background"]

    if (isDark) {
        try {
            DllCall("dwmapi\DwmSetWindowAttribute",
                "Ptr", CGui.Hwnd, "UInt", 20, "Int*", 1, "UInt", 4)
        } catch {
        }
        CGui.SetFont("s10 c" . Format("0x{:06X}", colors["textColor"]), "Consolas")
    } else {
        CGui.SetFont("s10", "Consolas")
    }

    DescText := CGui.Add("Text", "w620 Section", description)
    if (isDark)
        DescText.SetFont("s11 Bold c" . Format("0x{:06X}", colors["textColor"]))
    else
        DescText.SetFont("s11 Bold")

    ; Parse sections for the filter dropdown
    fullCombined := combinedContent
    sections     := Beacon_ParseSectionHeaders(combinedContent)

    taOpts := "w620 h490 ReadOnly VScroll"
    if (isDark) {
        taOpts .= " Background" . Format("0x{:06X}", colors["editBackground"])
        taOpts .= " c" . Format("0x{:06X}", colors["editText"])
    }
    TextArea := CGui.Add("Edit", taOpts, combinedContent)

    ; ── Bottom row: filter label + DDL left, Close right ──────────────
    CGui.Add("Text", "xm y+6 w90 h24 +0x200", "Filter section:")
    FilterDDL := CGui.Add("DropDownList", "x+6 w210 Choose1", sections)
    CloseBtn  := CGui.Add("Button", "x+16 w100 h30 Default +0x8000", "Close")

    if (isDark) {
        for ctrl in [CloseBtn, FilterDDL] {
            CloseBtn.SetFont("s10 c" . Format("0x{:06X}", 0xFFFFFF))
            CloseBtn.Opt("+Background" . Format("0x{:06X}", 0x3A3A3A))
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
    } else {
        CloseBtn.SetFont("s10 c" . Format("0x{:06X}", 0x000000))
        CloseBtn.Opt("+Background" . Format("0x{:06X}", 0xF5F5F5))
    }

    FilterDDL.OnEvent("Change", (*) => (
        TextArea.Value := Beacon_FilterToSection(fullCombined, FilterDDL.Text),
        SendMessage(0x00B1, 0, 0, TextArea)
    ))

    ; When TextArea regains focus (e.g. Shift+Tab from DDL, or screen reader
    ; landing on it), always clear any selection and place cursor at top.
    TextArea.OnEvent("Focus", (*) => SendMessage(0x00B1, 0, 0, TextArea))

    CloseBtn.OnEvent("Click",  (*) => CGui.Destroy())
    CGui.OnEvent("Escape",     (*) => CGui.Destroy())
    CGui.OnEvent("Close",      (*) => CGui.Destroy())

    CGui.Show("w660")
    ; Focus the text area (not the DDL) and clear any auto-selection
    TextArea.Focus()
    SendMessage(0x00B1, 0, 0, TextArea)
}

; Beacon_DetectAppShortcutType(processName, windowTitle)
;   Maps a process name (and browser window title for web apps) to the
;   matching ShortcutGuides key.  Returns "" when no match is found.
;
;   To add a new app: drop an entry in the relevant block below.
Beacon_DetectAppShortcutType(processName, windowTitle) {
    proc  := StrLower(processName)
    title := StrLower(windowTitle)

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
    isBrowser := (proc = "chrome.exe"       || proc = "firefox.exe"
               || proc = "msedge.exe"       || proc = "microsoftedge.exe"
               || proc = "brave.exe"        || proc = "opera.exe"
               || proc = "operagx.exe"      || proc = "vivaldi.exe"
               || proc = "waterfox.exe"     || proc = "librewolf.exe"
               || proc = "floorp.exe"       || proc = "thorium.exe"
               || proc = "arc.exe"          || proc = "iexplore.exe")

    if (isBrowser) {
        ; More-specific titles MUST appear before less-specific ones
        if (InStr(title, "youtube music"))
            return "YouTubeMusicShortcut"
        if (InStr(title, "youtube"))
            return "YouTubeShortcut"
        if (InStr(title, "google docs"))
            return "GoogleDocsShortcut"
        if (InStr(title, "google sheets"))
            return "GoogleSheetsShortcut"
        if (InStr(title, "google slides"))
            return "GoogleSlidesShortcut"
        if (InStr(title, "gmail") || InStr(title, "google mail"))
            return "GmailShortcut"
        if (InStr(title, "google meet"))
            return "GoogleMeetShortcut"
        if (InStr(title, "figma"))
            return "BrowserShortcut"   ; placeholder until a Figma guide is added
        if (InStr(title, "sharepoint"))
            return "SharePointOnlineShortcut"
        if (InStr(title, "onedrive"))
            return "OneDriveWebShortcut"
        if (InStr(title, "microsoft teams") || InStr(title, "teams.microsoft.com"))
            return "TeamsWebShortcut"
        if (InStr(title, "onenote"))
            return "OneNoteOnlineShortcut"
        if (InStr(title, "outlook") && (InStr(title, "microsoft") || InStr(title, "office") || InStr(title, "live.com") || InStr(title, "hotmail")))
            return "OutlookOnlineShortcut"
        if (InStr(title, "word") && (InStr(title, "microsoft") || InStr(title, "word online") || InStr(title, "office")))
            return "WordOnlineShortcut"
        if (InStr(title, "excel") && (InStr(title, "microsoft") || InStr(title, "excel online") || InStr(title, "office")))
            return "ExcelOnlineShortcut"
        if (InStr(title, "powerpoint") && (InStr(title, "microsoft") || InStr(title, "powerpoint online") || InStr(title, "office")))
            return "PowerPointOnlineShortcut"

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

; Initialize shortcut guides data
InitializeShortcutGuides()

; Remove any old .exe left over from a previous "Start automatically" move.
; Pass postMove=true when this instance was launched by the old one as part
; of a self-relocate, so a tray tip confirms the move completed.
Beacon_CleanupPendingFile(A_Args.Length > 0 && A_Args[1] = "/postmove")

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
`::`                                        ; pass backtick through when pressed alone
` & 1::ShowKeyboardMenu()                   ; Backtick + 1  → shortcuts menu
` & 2::ShowContextualShortcuts()            ; Backtick + 2  → auto-detect focused app
