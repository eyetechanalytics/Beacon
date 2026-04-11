# Beacon
Beacon (Ultimate Keyboard Shortcuts System)   Project Description: Beacon is a comprehensive, open-source productivity tool built on AutoHotkey v2.0+. It provides a centralized, menu-driven interface (accessible via AppsKey + G) that serves as a high-performance reference guide for keyboard shortcuts across the Windows ecosystem.


# Beacon: Ultimate Keyboard Shortcuts System

**Version:** 4.0.0  
**Platform:** Windows (AutoHotkey v2.0+)

Beacon is a modular, centralized reference system designed to boost productivity by providing instant access to keyboard shortcuts for dozens of applications.

## ✨ Features
- **Centralized Menu:** Access everything via a single hotkey (`AppsKey + G`).
- **Extensive Coverage:** Includes shortcuts for:
  - **Windows System:** File Explorer, Task Manager, Command Prompt, PowerShell, and more.
  - **Microsoft Office:** Full support for desktop apps and Office 365 Online.
  - **Google Suite:** Google Docs, Sheets, Slides, and Gmail.
  - **Multimedia:** YouTube, VLC, Audacity, and Reaper.
- **Accessibility Focused:** Comprehensive guides for JAWS, NVDA, Narrator, ZoomText, and Voice Access.
- **Modern UI:** - Enhanced Dark Mode that follows Windows system settings.
  - Borderless, clean menu design with mouse hover highlighting.
  - Fully navigable via keyboard (arrows/Enter) or mouse.

## 🚀 Getting Started
### Prerequisites
- [AutoHotkey v2.0 or higher](https://www.autohotkey.com/)

### Installation
1. Download the `Beacon.ahk` and `content.ahk` files.
2. Ensure both files are in the same folder.
3. Run `Beacon.ahk`.

### Usage
- **Open Menu:** Press `AppsKey + G` (or `Backtick + 1`).
- **Navigate:** Use Up/Down arrows or hover with your mouse.
- **Select:** Press `Enter` or click to view a shortcut guide.
- **Go Back/Close:** Press `Esc` or click the back/close buttons.

## 🛠 Modular Design
Beacon is designed for easy expansion. To add new shortcuts:
1. Define a new content function in `content.ahk`.
2. Register the metadata in `InitializeShortcutGuides()` within `Beacon.ahk`.
3. Add the item to the `MenuStructure` array.

## 📄 License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contact
- **Website:** [www.eyetechanalytics.com](http://www.eyetechanalytics.com)
- **Email:** beacon@eyetechanalytics.com
