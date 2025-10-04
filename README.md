# AggregateVolumeMenu

A simple macOS menu bar application that allows you to control the volume of your selected output device, including Aggregate Devices, right from your menu bar.

## Why?

If you use an Aggregate Audio Device on macOS, you might have noticed that the standard volume keys don't always work. This utility provides a volume slider and media key support for any output device, including aggregate ones. It also allows you to quickly switch between your available output devices.

## Features

*   **Menu Bar Access:** A convenient icon in your macOS menu bar.
*   **Device Discovery:** Automatically detects all available audio output devices.
*   **Device Switching:** Quickly change your default output device from the list.
*   **Volume Control:** A slider to control the volume of the currently selected device.
*   **Media Key Support:** Use your keyboard's volume up, down, and mute keys.
*   **Simple & Lightweight:** Built with native AppKit and CoreAudio for minimal resource usage.

## Screenshot

<img width="324" height="458" alt="Screenshot 2025-10-04 at 08 07 22" src="https://github.com/user-attachments/assets/484c4d54-6981-426d-83b1-795f3daa8f6d" />


## Getting Started

### Installation (Recommended)

You can download the latest pre-built version from the Releases page. Simply download the `.zip` file, extract it, and move `AggregateVolumeMenu.app` to your `/Applications` folder.

### Building from Source

If you prefer to build the application yourself, follow these steps.

#### Prerequisites

*   macOS
*   Xcode

#### Building and Running

1.  **Clone the repository:**
    ```sh
    git clone https://github.com/gurhanpolat/AggregateVolumeMenu.git
    cd AggregateVolumeMenu
    ```

2.  **Open the project in Xcode:**
    ```sh
    open AggregateVolumeMenu.xcodeproj
    ```

3.  **Run the application:**
    *   Select the `AggregateVolumeMenu` scheme and a target of `My Mac`.
    *   Click the "Run" button (or press `Cmd+R`).
    *   The application icon will appear in your menu bar.

## How It Works

The application is built using Swift and leverages two core macOS frameworks:
1.  **AppKit:** Used to create the menu bar icon (`NSStatusItem`) and the dynamic menu with its sliders (`NSSlider`) and checkboxes (`NSButton`).
2.  **CoreAudio:** This is the low-level framework used to interact with the system's audio hardware. The `AudioDeviceManager.swift` class contains the logic to:
    *   Query the system for all available audio output devices.
    *   Get and set the volume and mute state for a given device, including aggregate devices.
    *   Set the system's default output device.

The app also subclasses `NSApplication` to intercept media key presses (volume up, down, mute) and applies those changes to the currently selected default output device.

## Contributing

Contributions are welcome! Feel free to open an issue to report a bug or suggest a feature, or open a pull request with your improvements.

## License

This project is open-source.
