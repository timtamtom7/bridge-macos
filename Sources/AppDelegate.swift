import AppKit
import SwiftUI
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var deviceMonitor: DeviceMonitorService?
    let store: BridgeStore
    private var mainWindow: NSWindow?

    override init() {
        self.store = BridgeStore()
        super.init()
    }

    nonisolated func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            self.setupStatusItem()
            self.setupPopover()
            self.setupDeviceMonitor()
            self.setupMainMenu()
            self.store.loadSettings()
        }
    }

    nonisolated func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    // MARK: - Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem.button else { return }
        button.title = "Bridge"
        button.action = #selector(togglePopover)
        button.target = self
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 380, height: 520)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: ContentView(store: store))
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()
        NSApp.mainMenu = mainMenu

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu

        appMenu.addItem(withTitle: "About Bridge", action: #selector(showAbout), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Settings...", action: #selector(showSettings), keyEquivalent: ",")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit Bridge", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let devicesMenuItem = NSMenuItem()
        mainMenu.addItem(devicesMenuItem)
        let devicesMenu = NSMenu(title: "Devices")
        devicesMenuItem.submenu = devicesMenu

        let refreshItem = NSMenuItem(title: "Refresh Devices", action: #selector(refreshDevices), keyEquivalent: "r")
        devicesMenu.addItem(refreshItem)
    }

    private func setupDeviceMonitor() {
        let monitor = DeviceMonitorService.shared
        deviceMonitor = monitor
        monitor.startMonitoring()
    }

    // MARK: - Actions

    @objc private func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    private func closePopover() {
        popover.performClose(nil)
    }

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func showSettings() {
        Task { @MainActor in
            self.store.showSettings = true
        }
    }

    @objc private func refreshDevices() {
        Task { @MainActor in
            self.deviceMonitor?.refresh()
        }
    }

    private func openMainWindow() {
        mainWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        mainWindow?.title = "Bridge"
        mainWindow?.contentViewController = NSHostingController(rootView: ContentView(store: store))
        mainWindow?.makeKeyAndOrderFront(nil)
    }
}
