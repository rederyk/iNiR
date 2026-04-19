# KeePass Integration

The KeePass integration in iNiR provides a secure, fast, and visually integrated way to manage your passwords directly from the shell.

## Architecture

The system consists of three layers:

1.  **Backend Script (`scripts/quickshell-keepass`)**: A robust wrapper around `keepassxc-cli`. It handles the core logic, error reporting, and secure password caching using the system keyring.
2.  **Service (`services/KeePass.qml`)**: A background service that manages the database state (unlocked/locked), handles automated background locking via a timer, and exposes IPC targets.
3.  **UI Panel (`modules/keepass/KeepassPanel.qml`)**: A material-style overlay following the "SnowArch" aesthetic, providing search, entry management, and timer controls.

## Features

### 🔐 Secure Caching
Unlike standard scripts that might save passwords in plain text or volatile files, iNiR uses the **Secret Service API** (`secret-tool`). 
- The vault password is stored in your session keyring (Gnome Keyring or KWallet).
- The cache is automatically cleared when the timer expires or when manually locked.

### ⏳ Smart Timer System
The integration features a persistent background timer:
- **Interactive Slider**: Set the unlock duration (from 1 minute to 4 hours) before unlocking.
- **Title Bar Badge**: A live countdown timer (`MM:SS`) is visible in the title bar when the database is open.
- **Visual Progress**: A subtle progress bar inside the badge shows the remaining time relative to the initial setting.
- **Critical Alerts**: The timer turns **red** when less than 30 seconds remain.
- **Quick Reset**: Click the timer badge in the title bar to instantly reset the time to the maximum duration without re-entering the password.

### 🎨 Integrated UI
- **Auto-Focus**: Opening the panel automatically focuses the password field or the search field.
- **Pill Style**: All UI elements (selections, buttons, list items) use the "pill" shape and colors harmonized with your system theme (`colPrimary`).
- **High Contrast**: Text automatically inverts (`colOnPrimary`) when inside a selected "pill" for maximum readability.
- **Keyboard Friendly**: Fully navigable via keyboard. `Tab` cycles only between inputs and list; `Enter` selects or saves.

## Usage

### Commands
- `inir keepass toggle`: Opens or closes the KeePass panel.
- `inir keepass add`: Opens the panel in "Add Entry" mode, automatically pasting the primary selection into the password field.

### Configuration
The integration uses the following environment variables (defined in `~/.config/keepassqs/config`):
- `KP_VAULT_PATH`: Path to your `.kdbx` database.
- `KP_GEN_LANG`: Language for word-based password generation (default: `it`).

## Security Model
1.  **Locking**: The database is locked and the keyring cache is cleared immediately when the timer reaches zero or the "Lock" button is pressed.
2.  **Transparency**: Real error messages from `keepassxc-cli` (e.g., "Database locked by another process") are displayed directly in the UI for better diagnostics.
3.  **Clipboard**: Passwords copied to the clipboard are automatically cleared from the `cliphist` history after a short delay (if `cliphist` is active).
