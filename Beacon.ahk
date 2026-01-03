; =============================================================================
;                      Ultimate Keyboard Shortcuts System
;                      Version: 3.5.1 (Enhanced Dark Mode + Mouse Hover)
;                      (Dark mode applied to both menus and shortcut content dialogs)
;                      (Added responsive mouse hover highlighting)
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
Beacon_EnableDarkModeForApp() {
    try {
        ; Get Windows version
        winVer := VerCompare(A_OSVersion, "10.0.18362")
        if (winVer >= 0) { ; Windows 10 1903 or later
            isDark := Beacon_IsWindowsDarkMode()
            
            ; Enable dark mode for the application
            if (isDark) {
                ; Set window attribute for dark mode (Windows 10 1903+)
                DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", A_ScriptHwnd, "UInt", 20, "Int*", 1, "UInt", 4)
                
                ; Try to enable dark mode for menus and other UI elements
                try {
                    ; SetPreferredAppMode: 0 = Default, 1 = Allow Dark, 2 = Force Dark, 3 = Force Light
                    DllCall("uxtheme\SetPreferredAppMode", "Int", 2) ; Force dark mode
                    
                    ; Flush menu themes to apply changes
                    DllCall("uxtheme\FlushMenuThemes")
                    
                    ; Additional Windows 11 support
                    if (VerCompare(A_OSVersion, "10.0.22000") >= 0) { ; Windows 11
                        ; Use DWMWA_USE_IMMERSIVE_DARK_MODE for Windows 11
                        DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", A_ScriptHwnd, "UInt", 20, "Int*", 1, "UInt", 4)
                    }
                    
                    ; Try to set system theme for AutoHotkey process
                    DllCall("uxtheme\SetWindowTheme", "Ptr", A_ScriptHwnd, "WStr", "DarkMode_Explorer", "Ptr", 0)
                    
                } catch {
                    ; Some API calls might not be available on older systems
                }
            } else {
                ; Light mode
                try {
                    DllCall("uxtheme\SetPreferredAppMode", "Int", 3) ; Force light mode
                    DllCall("uxtheme\FlushMenuThemes")
                    DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", A_ScriptHwnd, "UInt", 20, "Int*", 0, "UInt", 4)
                } catch {
                    ; Ignore if not supported
                }
            }
        }
    } catch {
        ; Ignore errors on older Windows versions
    }
}

; Function to refresh theme when system theme changes
Beacon_RefreshApplicationTheme() {
    Beacon_EnableDarkModeForApp()
    
    ; Force refresh of any open menus
    try {
        DllCall("uxtheme\FlushMenuThemes")
        ; Send a message to refresh the application
        PostMessage(0x001A, 0, 0, A_ScriptHwnd) ; WM_WININICHANGE
    } catch {
        ; Ignore if calls fail
    }
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
    ShortcutGuides["ContactUsSection"] := Map(
        "title", "Contact Us",
        "description", "How to get in touch or find more information:",
        "contentCallback", GetContactUsContent
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
        ["Excel Shortcut commands", "ExcelShortcut"],
        ["WORD Shortcut commands", "WordShortcut"],
        ["PowerPoint Shortcut commands", "PowerPointShortcut"],
        ["Outlook Shortcut commands", "OutlookShortcut"]
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
    ["Multimedia Applications", [ ; Submenu
        ["YouTube Shortcuts", "YouTubeShortcut"],
        ["YouTube Music Shortcuts", "YouTubeMusicShortcut"],
        ["VLC Shortcuts", "VLCShortcut"],
        ["Windows Media Player Shortcuts", "WindowsMediaPlayerShortcut"],
        ["Audacity Shortcuts", "AudacityShortcut"],
        ["Reaper Shortcuts", "ReaperShortcut"]
    ]],
    [""], ; Separator
    ["Accessibility Options", [ ; Submenu
        ["Accessibility Overview", "AccessibilityShortcut"],
        ["Text Navigation (Keyboard)", "TextNavigationShortcut"],
        ["Windows Magnifier Shortcuts", "MagnifierShortcut"],
        ["Windows Narrator Shortcuts", "NarratorShortcut"],
        ["JAWS Screen Reader Shortcuts", "JAWSShortcut"],
        ["NVDA Screen Reader Shortcuts", "NVDAShortcut"],
        ["ZoomText Shortcuts", "ZoomTextShortcut"],
        ["Windows Voice Access", "VoiceAccessShortcut"],
        ["Microsoft Dictate Shortcuts", "MicrosoftDictateShortcut"],
        ["Accessibility Notes", "AccessibilityNotes"]
    ]],
    [""], ; Separator
    ["Contact Us", "ContactUsSection"]
    ; --- ADD NEW TOP-LEVEL MENU ITEMS OR SUBMENUS ABOVE THIS LINE ---
]

; =============================================================================
;                    CUSTOM GUI MENU SYSTEM WITH DARK MODE SUPPORT
; =============================================================================

; Global variables for menu management
Global CustomMenuGui := ""
Global CurrentMenuLevel := []
Global MenuHistory := []
Global CurrentTheme := Beacon_IsWindowsDarkMode()
Global MenuButtons := []  ; Array to store all menu buttons for navigation
Global SelectedIndex := 0  ; Currently selected menu item index
Global MenuActions := []   ; Array to store corresponding actions for each button
Global NavigationHotkeysActive := false  ; Track hotkey state

; NEW: Global variables for mouse hover management
Global MouseHoverIndex := 0  ; Currently hovered menu item index
Global MouseTrackingActive := false  ; Track mouse tracking state

; Function to check if theme has changed
Beacon_CheckThemeChange() {
    global CurrentTheme  ; Explicitly declare global access
    newTheme := Beacon_IsWindowsDarkMode()
    if (newTheme != CurrentTheme) {
        CurrentTheme := newTheme
        Beacon_RefreshApplicationTheme()
        return true
    }
    return false
}

; Enhanced menu function with theme checking
ShowKeyboardMenu() {
    ; Check if theme has changed since last time
    Beacon_CheckThemeChange()
    
    ; Refresh dark mode settings before showing menu
    Beacon_EnableDarkModeForApp()
    
    ; Small delay to ensure theme changes take effect
    Sleep(10)
    
    ; Show custom GUI menu instead of standard AutoHotkey menu
    ShowCustomMenu()
}

; Create custom themed menu GUI
ShowCustomMenu() {
    global CustomMenuGui, CurrentMenuLevel, MenuHistory, MenuButtons, SelectedIndex, MenuActions, MouseHoverIndex
    
    ; Get current theme colors
    colors := Beacon_GetThemeColors()
    isDark := Beacon_IsWindowsDarkMode()
    
    ; Close existing menu if open
    if (IsObject(CustomMenuGui)) {
        try {
            StopMouseTracking()  ; Stop mouse tracking
            CustomMenuGui.Destroy()
        } catch {
            ; Ignore if already destroyed
        }
    }
    
    ; Reset menu navigation arrays and mouse tracking
    MenuButtons := []
    MenuActions := []
    SelectedIndex := 0
    MouseHoverIndex := 0  ; Reset mouse hover
    
    ; Create new menu GUI
    CustomMenuGui := Gui("+AlwaysOnTop -MaximizeBox -MinimizeBox +LastFound", "Keyboard Shortcuts Menu")
    CustomMenuGui.BackColor := colors["background"]
    
    ; Apply dark mode to window
    if (isDark) {
        try {
            DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", CustomMenuGui.Hwnd, "UInt", 20, "Int*", 1, "UInt", 4)
        } catch {
            ; Ignore if not supported
        }
    }
    
    ; Set appropriate font and colors
    if (isDark) {
        CustomMenuGui.SetFont("s10 c" . Format("0x{:06X}", colors["textColor"]), "Segoe UI")
    } else {
        CustomMenuGui.SetFont("s10", "Segoe UI")
    }
    
    ; Create title
    titleText := CustomMenuGui.Add("Text", "x10 y10 w300 Center Section", "Keyboard Shortcuts Menu")
    if (isDark) {
        titleText.SetFont("s12 Bold c" . Format("0x{:06X}", colors["textColor"]))
    } else {
        titleText.SetFont("s12 Bold")
    }
    
    ; Add separator (non-focusable)
    separator := CustomMenuGui.Add("Text", "x10 y40 w300 h2 0x10 -TabStop") ; SS_SUNKEN style
    separator.Enabled := false
    
    ; Reset menu state
    CurrentMenuLevel := []
    MenuHistory := []
    
    ; Build menu items (this will handle the close button and sizing)
    itemCount := BuildMenuItems(CustomMenuGui, MenuStructure, colors, isDark)
    
    ; Set up events - only use standard GUI events
    CustomMenuGui.OnEvent("Close", CleanupAndClose)
    CustomMenuGui.OnEvent("Escape", CleanupAndClose)
    
    ; Activate keyboard navigation hotkeys
    ActivateNavigationHotkeys()
    
    ; Highlight first selectable item
    if (MenuButtons.Length > 0) {
        SelectedIndex := 1
        ApplyHighlight(SelectedIndex, colors, isDark)
    }
    
    ; Show menu centered on screen
    MonitorGetWorkArea(, &left, &top, &right, &bottom)
    menuWidth := 320
    menuHeight := 0
    
    ; Get the actual height of the GUI after building items
    CustomMenuGui.GetPos(,, &currentWidth, &menuHeight)
    
    ; Calculate center position
    centerX := (right - left - menuWidth) // 2 + left
    centerY := (bottom - top - menuHeight) // 2 + top
    
    CustomMenuGui.Show("w" . menuWidth . " x" . centerX . " y" . centerY)
}

; =============================================================================
;                    UNIFIED HIGHLIGHTING SYSTEM (MOUSE + KEYBOARD)
; =============================================================================

; Apply highlighting to menu item (used by both mouse and keyboard)
ApplyHighlight(index, colors, isDark) {
    global MenuButtons
    
    if (index > 0 && index <= MenuButtons.Length) {
        btn := MenuButtons[index]
        if (isDark) {
            ; Dark mode highlight - brighter blue with subtle border
            btn.Opt("+Background" . Format("0x{:06X}", 0x0078D4))
            btn.SetFont("s9 Bold c" . Format("0x{:06X}", 0xFFFFFF)) ; White text on blue
        } else {
            ; Light mode highlight with subtle border
            btn.Opt("+Background" . Format("0x{:06X}", 0x0078D4))
            btn.SetFont("s9 Bold c" . Format("0x{:06X}", 0xFFFFFF)) ; White text on blue
        }
        
        ; Force visual refresh
        btn.Redraw()
        try {
            DllCall("InvalidateRect", "Ptr", btn.Hwnd, "Ptr", 0, "Int", 1)
            DllCall("UpdateWindow", "Ptr", btn.Hwnd)
        } catch {
            ; Ignore if calls fail
        }
    }
}

; Remove highlighting from menu item (used by both mouse and keyboard)
RemoveHighlight(index, colors, isDark) {
    global MenuButtons
    
    if (index > 0 && index <= MenuButtons.Length) {
        btn := MenuButtons[index]
        
        if (isDark) {
            ; Dark mode normal - back to dark background
            btn.Opt("+Background" . Format("0x{:06X}", 0x2B2B2B))
            btn.SetFont("s9 c" . Format("0x{:06X}", 0xFFFFFF)) ; White text
        } else {
            ; Light mode normal - back to light background
            btn.Opt("+Background" . Format("0x{:06X}", 0xF8F8F8))
            btn.SetFont("s9 c" . Format("0x{:06X}", 0x000000)) ; Black text
        }
        
        ; Force visual refresh
        btn.Redraw()
        try {
            DllCall("InvalidateRect", "Ptr", btn.Hwnd, "Ptr", 0, "Int", 1)
            DllCall("UpdateWindow", "Ptr", btn.Hwnd)
        } catch {
            ; Ignore if calls fail
        }
    }
}

; =============================================================================
;                    SIMPLIFIED MOUSE HOVER SYSTEM
; =============================================================================

; Start mouse tracking - now uses WM_MOUSEMOVE instead of timer
StartMouseTracking() {
    global CustomMenuGui, MouseTrackingActive
    if (!MouseTrackingActive && IsObject(CustomMenuGui)) {
        MouseTrackingActive := true
        ; Use Windows message to track mouse movement over the GUI
        OnMessage(0x0200, MouseMoveHandler)  ; WM_MOUSEMOVE
    }
}

; Stop mouse tracking
StopMouseTracking() {
    global MouseTrackingActive
    if (MouseTrackingActive) {
        MouseTrackingActive := false
        ; Remove the mouse move message handler
        OnMessage(0x0200, MouseMoveHandler, 0)
    }
}

; Handle mouse movement over GUI
MouseMoveHandler(wParam, lParam, msg, hwnd) {
    global CustomMenuGui, MenuButtons, MouseHoverIndex, SelectedIndex

    if (!IsObject(CustomMenuGui) || hwnd != CustomMenuGui.Hwnd)
        return

    mouseX := lParam & 0xFFFF
    mouseY := (lParam >> 16) & 0xFFFF

    colors := Beacon_GetThemeColors()
    isDark := Beacon_IsWindowsDarkMode()

    newHoverIndex := 0
    margin := 1

    for index, btn in MenuButtons {
        try {
            btn.GetPos(&btnX, &btnY, &btnW, &btnH)

            if (mouseX >= btnX - margin && mouseX <= btnX + btnW + margin
             && mouseY >= btnY - margin && mouseY <= btnY + btnH + margin) {
                newHoverIndex := index
                break
            }
        } catch {
            continue
        }
    }

    if (newHoverIndex != MouseHoverIndex || newHoverIndex != SelectedIndex) {
        if (MouseHoverIndex > 0)
            RemoveHighlight(MouseHoverIndex, colors, isDark)

        if (newHoverIndex > 0) {
            if (SelectedIndex > 0 && SelectedIndex != newHoverIndex)
                RemoveHighlight(SelectedIndex, colors, isDark)

            ApplyHighlight(newHoverIndex, colors, isDark)
            SelectedIndex := newHoverIndex
        }

        MouseHoverIndex := newHoverIndex
    }
}

; =============================================================================
;                    UPDATED BUILD MENU ITEMS WITH MOUSE SUPPORT
; =============================================================================

; Build menu items recursively - UPDATED: Uses Text controls with mouse hover support
BuildMenuItems(gui, structure, colors, isDark, startY := 80) {
    global MenuButtons, MenuActions
    
    yPos := startY ; Starting position 
    itemCount := 0
    
    for itemDefinition in structure {
        if (itemDefinition.Length = 1 && itemDefinition[1] = "") {
            ; Separator - make it non-focusable and disabled
            separator := gui.Add("Text", "x10 y" . yPos . " w300 h1 0x10 -TabStop", "") ; SS_SUNKEN style, no tab stop
            separator.Enabled := false  ; Disable to prevent focus
            yPos += 10
        } else if (itemDefinition.Length = 2) {
            label := itemDefinition[1]
            action := itemDefinition[2]
            
            ; Create menu item using Text control instead of Button - COMPLETELY BORDERLESS
            if IsObject(action) {
                ; Submenu - add arrow indicator
                btnText := label . " ►"
                btn := gui.Add("Text", "x10 y" . yPos . " w300 h28 Center 0x200", btnText) ; SS_NOTIFY for click events
                btn.OnEvent("Click", ShowSubmenu.Bind(action, label, colors, isDark))
                
                ; Store for navigation
                MenuButtons.Push(btn)
                MenuActions.Push({type: "submenu", action: action, label: label, colors: colors, isDark: isDark})
            } else {
                ; Regular item
                btn := gui.Add("Text", "x10 y" . yPos . " w300 h28 Center 0x200", label) ; SS_NOTIFY for click events
                btn.OnEvent("Click", MenuItemClick.Bind(action))
                
                ; Store for navigation
                MenuButtons.Push(btn)
                MenuActions.Push({type: "item", action: action})
            }
            
            ; Style text control for theme - COMPLETELY BORDERLESS by default
            if (isDark) {
                btn.SetFont("s9 c" . Format("0x{:06X}", 0xFFFFFF)) ; White text
                ; Set custom background color for dark mode
                btn.Opt("+Background" . Format("0x{:06X}", 0x2B2B2B)) ; Match menu background
            } else {
                btn.SetFont("s9 c" . Format("0x{:06X}", 0x000000)) ; Black text
                ; Set light background color for light mode
                btn.Opt("+Background" . Format("0x{:06X}", 0xF8F8F8)) ; Very light gray
            }
            
            yPos += 32
            itemCount++
        }
    }
    
    ; Add close button at the bottom - Also use Text control
    closeBtn := gui.Add("Text", "x10 y" . (yPos + 10) . " w100 h30 Center 0x200", "Close") ; SS_NOTIFY for click events
    if (isDark) {
        closeBtn.SetFont("s9 c" . Format("0x{:06X}", 0xFFFFFF)) ; White text
        closeBtn.Opt("+Background" . Format("0x{:06X}", 0x2B2B2B)) ; Match background
    } else {
        closeBtn.SetFont("s9 c" . Format("0x{:06X}", 0x000000)) ; Black text
        closeBtn.Opt("+Background" . Format("0x{:06X}", 0xF8F8F8)) ; Very light gray
    }
    closeBtn.OnEvent("Click", (*) => gui.Destroy())
    
    ; Add close button to navigation (always last)
    MenuButtons.Push(closeBtn)
    MenuActions.Push({type: "close"})
    
    ; Add keyboard shortcuts help text (also non-focusable)
    helpText := gui.Add("Text", "x10 y" . (yPos + 45) . " w300 Center -TabStop", "Use ↑↓ arrows to navigate, Enter to select, Esc to go back/close")
    helpText.Enabled := false  ; Disable to prevent focus
    if (isDark) {
        helpText.SetFont("s8 c" . Format("0x{:06X}", colors["textColor"]))
    } else {
        helpText.SetFont("s8")
    }
    
    ; Adjust GUI height based on content
    finalHeight := yPos + 80
    gui.Move(,, 320, finalHeight)
    
    ; Start mouse tracking after all items are created
    StartMouseTracking()
    
    return itemCount
}

; Handle submenu clicks - UPDATED: Back button uses Text control and includes mouse tracking
ShowSubmenu(submenuStructure, title, colors, isDark, *) {
    global CustomMenuGui, CurrentMenuLevel, MenuHistory, MenuButtons, SelectedIndex, MenuActions, MouseHoverIndex
    
    ; Stop existing mouse tracking
    StopMouseTracking()
    
    ; Store current menu in history
    MenuHistory.Push([CurrentMenuLevel, title])
    CurrentMenuLevel := submenuStructure
    
    ; Close current menu
    CustomMenuGui.Destroy()
    
    ; Reset navigation arrays and mouse tracking
    MenuButtons := []
    MenuActions := []
    SelectedIndex := 0
    MouseHoverIndex := 0  ; Reset mouse hover
    
    ; Create submenu
    CustomMenuGui := Gui("+AlwaysOnTop -MaximizeBox -MinimizeBox +LastFound", "Shortcuts: " . title)
    CustomMenuGui.BackColor := colors["background"]
    
    ; Apply dark mode
    if (isDark) {
        try {
            DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", CustomMenuGui.Hwnd, "UInt", 20, "Int*", 1, "UInt", 4)
        } catch {
        }
    }
    
    ; Set font
    if (isDark) {
        CustomMenuGui.SetFont("s10 c" . Format("0x{:06X}", colors["textColor"]), "Segoe UI")
    } else {
        CustomMenuGui.SetFont("s10", "Segoe UI")
    }
    
    ; Create title
    titleText := CustomMenuGui.Add("Text", "x10 y10 w300 Center Section", title)
    if (isDark) {
        titleText.SetFont("s12 Bold c" . Format("0x{:06X}", colors["textColor"]))
    } else {
        titleText.SetFont("s12 Bold")
    }
    
    ; Add back button if we have history - UPDATED: Use Text control instead of Button
    if (MenuHistory.Length > 0) {
        backBtn := CustomMenuGui.Add("Text", "x10 y35 w100 h25 Center 0x200", "◄ Back") ; SS_NOTIFY for click events
        if (isDark) {
            backBtn.SetFont("s9 c" . Format("0x{:06X}", 0xFFFFFF)) ; White text
            backBtn.Opt("+Background" . Format("0x{:06X}", 0x2B2B2B)) ; Match background
        } else {
            backBtn.SetFont("s9 c" . Format("0x{:06X}", 0x000000)) ; Black text
            backBtn.Opt("+Background" . Format("0x{:06X}", 0xF8F8F8)) ; Very light gray
        }
        backBtn.OnEvent("Click", GoBack.Bind(colors, isDark))
        
        ; Add back button to navigation (always first)
        MenuButtons.Push(backBtn)
        MenuActions.Push({type: "back", colors: colors, isDark: isDark})
        
        ; Add separator below back button (non-focusable)
        separator := CustomMenuGui.Add("Text", "x10 y65 w300 h2 0x10 -TabStop")
        separator.Enabled := false
        yOffset := 75
    } else {
        ; Add separator below title (non-focusable)
        separator := CustomMenuGui.Add("Text", "x10 y40 w300 h2 0x10 -TabStop")
        separator.Enabled := false
        yOffset := 50
    }
    
    ; Build submenu items with correct Y offset (this will start mouse tracking)
    BuildMenuItems(CustomMenuGui, submenuStructure, colors, isDark, yOffset)
    
    ; Set up keyboard event handling
    CustomMenuGui.OnEvent("Close", CleanupAndClose)
    CustomMenuGui.OnEvent("Escape", CleanupAndClose)
    
    ; Activate keyboard navigation hotkeys
    ActivateNavigationHotkeys()
    
    ; Highlight first selectable item
    if (MenuButtons.Length > 0) {
        SelectedIndex := 1
        ApplyHighlight(SelectedIndex, colors, isDark)
    }
    
    ; Show submenu centered on screen
    MonitorGetWorkArea(, &left, &top, &right, &bottom)
    menuWidth := 320
    menuHeight := 0
    
    ; Get the actual height of the GUI after building items
    CustomMenuGui.GetPos(,, &currentWidth, &menuHeight)
    
    ; Calculate center position
    centerX := (right - left - menuWidth) // 2 + left
    centerY := (bottom - top - menuHeight) // 2 + top
    
    CustomMenuGui.Show("w" . menuWidth . " x" . centerX . " y" . centerY)
}

; Handle back button
GoBack(colors, isDark, *) {
    global CustomMenuGui, CurrentMenuLevel, MenuHistory  ; Explicitly declare global access
    
    if (MenuHistory.Length > 0) {
        lastMenu := MenuHistory.Pop()
        CurrentMenuLevel := lastMenu[1]
        title := lastMenu[2]
        
        ; Recreate previous menu
        if (CurrentMenuLevel.Length = 0) {
            ; Back to main menu
            ShowCustomMenu()
        } else {
            ShowSubmenu(CurrentMenuLevel, title, colors, isDark)
        }
    }
}

; Handle menu item clicks
MenuItemClick(shortcutType, *) {
    global CustomMenuGui  ; Explicitly declare global access
    
    ; Close menu
    if (IsObject(CustomMenuGui)) {
        ; Stop mouse tracking and deactivate navigation hotkeys
        StopMouseTracking()
        DeactivateNavigationHotkeys()
        CustomMenuGui.Destroy()
    }
    
    ; Show shortcut guide
    ShowShortcutGuide(shortcutType)
}

; Clean up and close menu - UPDATED: Now includes mouse tracking cleanup
CleanupAndClose(*) {
    global CustomMenuGui
    
    ; Stop mouse tracking
    StopMouseTracking()
    
    ; Deactivate navigation hotkeys
    DeactivateNavigationHotkeys()
    
    ; Destroy GUI
    if (IsObject(CustomMenuGui)) {
        CustomMenuGui.Destroy()
    }
}

; =============================================================================
;                           KEYBOARD NAVIGATION FUNCTIONS
; =============================================================================

; Activate navigation hotkeys
ActivateNavigationHotkeys() {
    global NavigationHotkeysActive  ; Explicitly declare global access
    
    if (!NavigationHotkeysActive) {
        try {
            Hotkey("Up", NavigateUpHotkey, "On")
            Hotkey("Down", NavigateDownHotkey, "On") 
            Hotkey("Left", NavigateUpHotkey, "On")
            Hotkey("Right", NavigateDownHotkey, "On")
            Hotkey("Enter", SelectCurrentHotkey, "On")
            Hotkey("Escape", EscapeHotkey, "On")
            Hotkey("Tab", NavigateDownHotkey, "On")
            NavigationHotkeysActive := true
        } catch Error as e {
            ; Ignore hotkey activation errors
        }
    }
}

; Deactivate navigation hotkeys
DeactivateNavigationHotkeys() {
    global NavigationHotkeysActive  ; Explicitly declare global access
    
    if (NavigationHotkeysActive) {
        try {
            Hotkey("Up", "Off")
            Hotkey("Down", "Off")
            Hotkey("Left", "Off")
            Hotkey("Right", "Off")
            Hotkey("Enter", "Off")
            Hotkey("Escape", "Off")
            Hotkey("Tab", "Off")
            NavigationHotkeysActive := false
        } catch {
            ; Ignore if hotkeys don't exist
        }
    }
}

; Hotkey functions
NavigateUpHotkey(*) {
    global CustomMenuGui
    
    if (IsObject(CustomMenuGui)) {
        colors := Beacon_GetThemeColors()
        isDark := Beacon_IsWindowsDarkMode()
        NavigateUp(colors, isDark)
    }
}

NavigateDownHotkey(*) {
    global CustomMenuGui
    
    if (IsObject(CustomMenuGui)) {
        colors := Beacon_GetThemeColors()
        isDark := Beacon_IsWindowsDarkMode()
        NavigateDown(colors, isDark)
    }
}

SelectCurrentHotkey(*) {
    global CustomMenuGui
    
    if (IsObject(CustomMenuGui)) {
        SelectCurrentItem()
    }
}

EscapeHotkey(*) {
    global CustomMenuGui, MenuHistory
    
    if (IsObject(CustomMenuGui)) {
        colors := Beacon_GetThemeColors()
        isDark := Beacon_IsWindowsDarkMode()
        ; Smart Escape: Go back if in submenu, close if in main menu
        if (MenuHistory.Length > 0) {
            ; We're in a submenu, so go back
            GoBack(colors, isDark)
        } else {
            ; We're in the main menu, so close
            CleanupAndClose()
        }
    }
}

; Navigate up in the menu
NavigateUp(colors, isDark) {
    global SelectedIndex, MenuButtons, MouseHoverIndex
    
    if (MenuButtons.Length = 0) {
        return
    }
    
    ; Remove any existing mouse hover highlight first
    if (MouseHoverIndex > 0) {
        RemoveHighlight(MouseHoverIndex, colors, isDark)
        MouseHoverIndex := 0
    }
    
    ; Remove highlight from current item
    if (SelectedIndex > 0 && SelectedIndex <= MenuButtons.Length) {
        RemoveHighlight(SelectedIndex, colors, isDark)
    }
    
    ; Move to previous item
    SelectedIndex--
    if (SelectedIndex < 1) {
        SelectedIndex := MenuButtons.Length ; Wrap to last item
    }
    
    ; Highlight new item
    ApplyHighlight(SelectedIndex, colors, isDark)
}

; Navigate down in the menu
NavigateDown(colors, isDark) {
    global SelectedIndex, MenuButtons, MouseHoverIndex
    
    if (MenuButtons.Length = 0) {
        return
    }
    
    ; Remove any existing mouse hover highlight first
    if (MouseHoverIndex > 0) {
        RemoveHighlight(MouseHoverIndex, colors, isDark)
        MouseHoverIndex := 0
    }
    
    ; Remove highlight from current item
    if (SelectedIndex > 0 && SelectedIndex <= MenuButtons.Length) {
        RemoveHighlight(SelectedIndex, colors, isDark)
    }
    
    ; Move to next item
    SelectedIndex++
    if (SelectedIndex > MenuButtons.Length) {
        SelectedIndex := 1 ; Wrap to first item
    }
    
    ; Highlight new item
    ApplyHighlight(SelectedIndex, colors, isDark)
}

; Highlight the selected menu item - UPDATED: Uses unified highlighting system
HighlightMenuItem(index, colors, isDark) {
    ApplyHighlight(index, colors, isDark)
}

; Select the currently highlighted item
SelectCurrentItem() {
    global SelectedIndex, MenuActions, CustomMenuGui
    
    if (SelectedIndex > 0 && SelectedIndex <= MenuActions.Length) {
        action := MenuActions[SelectedIndex]
        
        switch action.type {
            case "item":
                ; Clean up and close menu, then show shortcut guide
                StopMouseTracking()
                DeactivateNavigationHotkeys()
                CustomMenuGui.Destroy()
                ShowShortcutGuide(action.action)
            case "submenu":
                ; Show submenu
                ShowSubmenu(action.action, action.label, action.colors, action.isDark)
            case "back":
                ; Go back to previous menu
                GoBack(action.colors, action.isDark)
            case "close":
                ; Clean up and close menu
                CleanupAndClose()
        }
    }
}

; =============================================================================
;                    THEME MONITORING SYSTEM
; =============================================================================

; Timer to periodically check for theme changes
Beacon_SetupThemeMonitoring() {
    ; Check theme every 2 seconds
    SetTimer(Beacon_CheckThemeChange, 2000)
}

; Function to handle Windows theme change messages
Beacon_OnThemeChange() {
    ; Refresh application theme when Windows theme changes
    Beacon_RefreshApplicationTheme()
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
    
    ; Create text area with improved options
    textAreaOptions := "w620 h520 ReadOnly VScroll"
    if (isDark) {
        textAreaOptions .= " Background" . Format("0x{:06X}", colors["editBackground"]) 
        textAreaOptions .= " c" . Format("0x{:06X}", colors["editText"])
    }
    
    TextArea := ShortcutGui.Add("Edit", textAreaOptions, content)
    
    ; Add improved button styling
    buttonOptions := "w100 h30 Default +0x8000" ; BS_FLAT style
    CloseButton := ShortcutGui.Add("Button", buttonOptions, "Close")
    if (isDark) {
        CloseButton.SetFont("s10 c" . Format("0x{:06X}", 0xFFFFFF)) ; White text
        CloseButton.Opt("+Background" . Format("0x{:06X}", 0x3A3A3A)) ; Dark gray background
        try {
            DllCall("uxtheme\SetWindowTheme", "Ptr", CloseButton.Hwnd, "WStr", "DarkMode_Explorer", "Ptr", 0)
        } catch {
            ; Ignore if theming fails
        }
    } else {
        CloseButton.SetFont("s10 c" . Format("0x{:06X}", 0x000000)) ; Black text
        CloseButton.Opt("+Background" . Format("0x{:06X}", 0xF5F5F5)) ; Light gray background
    }
    
    CloseButton.OnEvent("Click", (*) => ShortcutGui.Destroy())
    ShortcutGui.OnEvent("Escape", (*) => ShortcutGui.Destroy())
    ShortcutGui.OnEvent("Close", (*) => ShortcutGui.Destroy())
    
    ; Apply additional dark mode theming if available
    if (isDark) {
        try {
            ; Try to apply dark theme to controls
            DllCall("uxtheme\SetWindowTheme", "Ptr", TextArea.Hwnd, "WStr", "DarkMode_Explorer", "Ptr", 0)
            DllCall("uxtheme\SetWindowTheme", "Ptr", CloseButton.Hwnd, "WStr", "DarkMode_Explorer", "Ptr", 0)
        } catch {
            ; Ignore if theming calls fail
        }
    }
    
    ; Center the window on screen
    MonitorGetWorkArea(, &left, &top, &right, &bottom)
    dialogWidth := 640
    dialogHeight := 600
    centerX := (right - left - dialogWidth) // 2 + left
    centerY := (bottom - top - dialogHeight) // 2 + top
    
    ShortcutGui.Show("w" . dialogWidth . " h" . dialogHeight . " x" . centerX . " y" . centerY)
    
    TextArea.Focus()
    SendMessage(0xB1, 0, 0, TextArea.Hwnd) ; EM_SETSEL to scroll to top
}

; =============================================================================
;                           SHORTCUT CONTENT FORMATTING
; =============================================================================
FormatHeader(titleText) {
    return "`n===============================================`n"
        . "      " . StrUpper(titleText) . "`n"
        . "===============================================`n`n"
}

; =============================================================================
;                      CONTENT FUNCTIONS (INCLUDE EXTERNAL FILE)
; =============================================================================

#Include %A_ScriptDir%\content.ahk

; =============================================================================
;                           INITIALIZATION
; =============================================================================

; Initialize shortcut guides data
InitializeShortcutGuides()

; Initialize dark mode support
Beacon_EnableDarkModeForApp()

; Set up theme monitoring
Beacon_SetupThemeMonitoring()

; Register for theme change notifications
OnMessage(0x001A, (*) => Beacon_OnThemeChange()) ; WM_WININICHANGE

; =============================================================================
;                           HOTKEYS
; =============================================================================
; Hotkey for keyboard shortcuts menu - use this for standalone version
; Comment out these lines if adding to your main script with different hotkeys
;AppsKey & g::ShowKeyboardMenu()

; Example of an alternative hotkey (Ctrl + Shift + H)
; ^+h::ShowKeyboardMenu()

; If you want to use the "` & 1" hotkey:
; Ensure the backtick is not remapped if it's used elsewhere in your script.
; The `::`` line allows the backtick to function normally when pressed alone.
`::`
` & 1::ShowKeyboardMenu()