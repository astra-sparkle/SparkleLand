# Sparkle Land

[![Crowdin](https://badges.crowdin.net/sparkleland/localized.svg)](https://crowdin.com/project/sparkleland)

Sparkle Land is a KDE Plasma applet designed to bring a GNOME-inspired panel experience to the desktop, covering time, date, media playback, and notifications in a compact layout.

This project is built around the latest Qt and Plasma APIs and keeps a lightweight, pure QML implementation.

## Overview

- Clock and date display
- Calendar navigation
- Media playback metadata
- Notification overview and banner support
- Compact panel layout with theme-aware colors

## Current state

- The applet is intentionally implemented in QML only.
- Notification behavior is treated as a best-effort integration because KDE's notification stack is tightly coupled to the desktop environment.
- The project focuses on a clean Plasma panel experience without introducing custom backend services.

## Design notes

- The app uses QPalette rather than Kirigami defaults for accent colors because some older themes do not expose a dynamic accent color consistently.
- This avoids falling back to the default Plasma blue in themes such as Orchid when the palette is incomplete.
- The panel keeps a compact and highly theme-aware appearance while preserving compatibility with modern KDE releases.

## Project status

- 100% QML
- Built for current Qt / Plasma development builds
- Planned for continued refinement as the KDE notification APIs evolve
