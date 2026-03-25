# Bridge — Brand Guidelines

## App Overview
Bridge is a macOS app that connects to your iOS device via USB and lets you manage photos, contacts, and backups — all from your Mac. No cloud, no account, just a direct bridge between your devices.

---

## Icon Concept

**Visual:** Two interlocking device shapes — an iPhone silhouette and a MacBook silhouette — connected by a subtle lightning bolt or USB plug in the center.
- A rounded square icon (standard macOS shape)
- Left half: iPhone outline in blue
- Right half: MacBook outline in blue
- Center: a connecting bridge/link symbol
- Sizes: 16, 32, 64, 128, 256, 512, 1024

**Alternative concept:** A simple USB-C plug bridging two dots (iOS ↔ macOS), in a soft gradient blue on white background.

---

## Color Palette

| Role | Hex | Usage |
|------|-----|-------|
| Primary Blue | `#007AFF` | Connected state, primary actions, tab highlights |
| Light Blue | `#4DA3FF` | Hover states, secondary highlights |
| Deep Blue | `#0056B3` | Active/pressed states |
| Background Light | `#F5F7FA` | Main background (light) |
| Background Dark | `#1C1C1E` | Main background (dark) |
| Surface Light | `#FFFFFF` | Cards, panels (light) |
| Surface Dark | `#2C2C2E` | Cards, panels (dark) |
| Text Primary Light | `#1A1A1A` | Headings, body (light) |
| Text Primary Dark | `#F5F5F7` | Headings, body (dark) |
| Text Secondary | `#8E8E93` | Subtitles, labels |
| Success Green | `#34C759` | Connected indicator, sync complete |
| Warning Orange | `#FF9500` | Low battery, sync in progress |
| Destructive Red | `#FF3B30` | Disconnect, delete, errors |
| Divider | `#E5E5EA` (light) / `#38383A` (dark) |

---

## Typography

- **Display / Header:** SF Pro Display, Bold — 20px
- **Section Headings:** SF Pro Text, Semibold — 15px
- **Body:** SF Pro Text, Regular — 13px
- **Caption / Metadata:** SF Pro Text, Regular — 11px, secondary color
- **Monospace (serial numbers, IDs):** SF Mono, Regular — 12px

**Font Stack:**
```
font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "SF Pro Display", sans-serif;
```

---

## Visual Motif

**Theme:** "Device Unity" — clean, technical, Apple-inspired. Feels like an extension of the Finder/System Settings ecosystem.

- **Header bar:** Device icon + name + iOS version, always visible at top
- **Tab bar:** 4 tabs (Device, Photos, Contacts, Backup) with SF Symbols icons
- **Device card:** Rounded rectangle showing device model, storage used/free, battery level
- **Status indicators:** Pulsing green dot for connected, gray for disconnected
- **Progress bars:** Thin, rounded, blue fill for sync/upload progress
- **Empty states:** Illustrated iPhone with cable unplugged, friendly copy

**Spatial rhythm:** 8pt grid. Window fixed at 480×520. Content padding 16px.

---

## macOS-Specific Behavior

- **Window:** Fixed-size `NSWindow` at 480×520. Non-resizable.
- **Menu Bar:** No persistent icon. Uses Dock icon.
- **Tabs:** `NSTabView` with icon+label tab style.
- **Device connection:** Uses `ideviceinfo` / libimobiledevice via shell.
- **Dark Mode:** Full support.
- **Keyboard shortcuts:** `⌘R` refresh, `⌘⇧B` backup now, `⌘E` eject device.

---

## Sizes & Behavior

| Element | Size |
|---------|------|
| Window | 480×520 (fixed) |
| Header height | 60px |
| Tab bar height | 40px |
| Row/card padding | 12px |
| Icon size (tabs) | 16×16 |
| Icon size (header) | 24×24 |

Status bar at bottom: 24px, shows connection status and last sync time.
