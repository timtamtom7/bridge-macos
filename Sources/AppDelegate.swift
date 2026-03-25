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

    nonisolated init() {
        self.store = MainActor.assumeIsolated { BridgeStore() }
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

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "iphone", accessibilityDescription: "Bridge")
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 480, height: 520)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: ContentView(store: store))
    }

    @objc private func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown { popover.performClose(nil) }
            else { popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY) }
        }
    }

    private func setupDeviceMonitor() {
        deviceMonitor = DeviceMonitorService(store: store)
        deviceMonitor?.startMonitoring()
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Bridge", action: #selector(showAbout), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit Bridge", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        mainMenu.addItem(NSMenuItem(label: "Bridge", submenu: appMenu))

        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "Open Bridge", action: #selector(openMainWindow), keyEquivalent: "o")
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "Close Window", action: #selector(closeMainWindow), keyEquivalent: "w")
        mainMenu.addItem(NSMenuItem(label: "File", submenu: fileMenu))

        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m")
        mainMenu.addItem(NSMenuItem(label: "Window", submenu: windowMenu))

        NSApplication.shared.mainMenu = mainMenu
    }

    @objc private func openMainWindow() {
        if mainWindow == nil {
            mainWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            mainWindow?.title = "Bridge"
            mainWindow?.contentViewController = NSHostingController(rootView: ContentView(store: store))
            mainWindow?.center()
            mainWindow?.setFrameAutosaveName("BridgeMainWindow")
            mainWindow?.isReleasedWhenClosed = false
        }
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    @objc private func closeMainWindow() { mainWindow?.close() }
    @objc private func showAbout() { NSApplication.shared.orderFrontStandardAboutPanel(nil) }
}
