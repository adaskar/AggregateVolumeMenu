# AggregateVolumeMenu
AggregateVolumeMenu gives you the ability to change the volume of the aggregate sound device

A simple macOS menu bar application that allows you to control the volume of multiple audio output devices simultaneously, right from your menu bar.

## Why?

If you use an Aggregate Audio Device on macOS or have multiple audio outputs (like built-in speakers, headphones, and an external monitor), you know that macOS only provides a master volume control. `AggregateVolumeMenu` creates a menu bar item that lists all your output devices, giving you individual volume and mute controls for each one.

## Features

*   **Menu Bar Access:** A convenient icon in your macOS menu bar.
*   **Device Discovery:** Automatically detects all available audio output devices.
*   **Simple & Lightweight:** Built with native AppKit and CoreAudio for minimal resource usage.

## Screenshot

<img width="570" height="452" alt="image" src="https://github.com/user-attachments/assets/4f68dc46-7ab8-4ee2-ac0a-e24d1bf2e2df" />


## Getting Started

### Prerequisites

*   macOS
*   Xcode

### Building and Running

1.  **Clone the repository:**
    ```sh
    git clone <your-repository-url>
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
2.  **CoreAudio:** This is the low-level framework used to interact with the system's audio hardware. The `AudioDevice.swift` helper class contains the logic to:
    *   Query the system for all available audio output devices.
    *   Get and set the volume for each device.
    *   Get and set the mute state for each device.

When the application launches, it queries `CoreAudio` for devices and dynamically builds the menu. It then listens for UI events (like a slider moving) and translates them back into `CoreAudio` commands to change the volume or mute state of the corresponding device.

## Contributing

Contributions are welcome! Feel free to open an issue to report a bug or suggest a feature, or open a pull request with your improvements.

## License

This project is open-source.
