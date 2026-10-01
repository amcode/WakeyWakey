import AppKit
import ServiceManagement
import WakeyWakeyCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let settings = Settings()
    private lazy var preventer = IOKitSleepPreventer(preventDisplaySleep: settings.preventDisplaySleep)
    private lazy var controller = AwakeController(preventer: preventer, scheduler: TimerScheduler())
    private var tickTimer: Timer?

    // MARK: Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusItemClicked(_:))
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

        controller.onStateChange = { [weak self] _ in self?.refresh() }

        if settings.activateOnLaunch {
            controller.activate(for: settings.defaultDuration)
        }
        refresh()

        // Keep the "Xm left" text fresh.
        tickTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.refreshTooltip()
        }
        RunLoop.main.add(tickTimer!, forMode: .common)
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.shutdown()
    }

    // MARK: Click handling — left toggles, right opens the menu

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showMenu()
        } else {
            controller.toggle(duration: settings.defaultDuration)
        }
    }

    private func showMenu() {
        let menu = buildMenu()
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil   // so the next left-click toggles instead of opening the menu
    }

    // MARK: UI

    private func refresh() {
        let state = controller.state
        let image = NSImage(systemSymbolName: MenuBarPresenter.symbol(for: state),
                            accessibilityDescription: MenuBarPresenter.tooltip(for: state, now: Date()))
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.appearsDisabled = !controller.isAwake
        refreshTooltip()
    }

    private func refreshTooltip() {
        statusItem.button?.toolTip = MenuBarPresenter.tooltip(for: controller.state, now: Date())
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        let now = Date()

        let status = NSMenuItem(title: MenuBarPresenter.statusLine(for: controller.state, now: now),
                                action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())

        let toggle = NSMenuItem(title: MenuBarPresenter.toggleMenuTitle(isAwake: controller.isAwake),
                                action: #selector(toggleAwake), keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)

        // Activate for…
        let durationMenu = NSMenu()
        for duration in Duration.presets {
            let item = NSMenuItem(title: duration.displayName, action: #selector(activateFor(_:)), keyEquivalent: "")
            item.representedObject = duration.rawMinutes
            item.target = self
            durationMenu.addItem(item)
        }
        let durationItem = NSMenuItem(title: "Activate for", action: nil, keyEquivalent: "")
        durationItem.submenu = durationMenu
        menu.addItem(durationItem)
        menu.addItem(.separator())

        // Preferences
        let prefs = NSMenu()

        let defaultMenu = NSMenu()
        for duration in Duration.presets {
            let item = NSMenuItem(title: duration.displayName, action: #selector(setDefaultDuration(_:)), keyEquivalent: "")
            item.representedObject = duration.rawMinutes
            item.target = self
            item.state = duration == settings.defaultDuration ? .on : .off
            defaultMenu.addItem(item)
        }
        let defaultItem = NSMenuItem(title: "Default duration", action: nil, keyEquivalent: "")
        defaultItem.submenu = defaultMenu
        prefs.addItem(defaultItem)

        let onLaunch = NSMenuItem(title: "Activate at launch", action: #selector(toggleActivateOnLaunch), keyEquivalent: "")
        onLaunch.target = self
        onLaunch.state = settings.activateOnLaunch ? .on : .off
        prefs.addItem(onLaunch)

        let display = NSMenuItem(title: "Keep display on", action: #selector(toggleDisplaySleep), keyEquivalent: "")
        display.target = self
        display.state = settings.preventDisplaySleep ? .on : .off
        display.toolTip = "Off: the screen may dim and lock, but the Mac won't sleep."
        prefs.addItem(display)

        let login = NSMenuItem(title: "Launch at login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        prefs.addItem(login)

        let prefsItem = NSMenuItem(title: "Preferences", action: nil, keyEquivalent: "")
        prefsItem.submenu = prefs
        menu.addItem(prefsItem)

        menu.addItem(.separator())
        let about = NSMenuItem(title: "About \(MenuBarPresenter.appName)", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)
        menu.addItem(NSMenuItem(title: "Quit \(MenuBarPresenter.appName)",
                                action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    // MARK: Actions

    @objc private func toggleAwake() {
        controller.toggle(duration: settings.defaultDuration)
    }

    @objc private func activateFor(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? Int else { return }
        controller.activate(for: Duration(rawMinutes: raw))
    }

    @objc private func setDefaultDuration(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? Int else { return }
        settings.defaultDuration = Duration(rawMinutes: raw)
    }

    @objc private func toggleActivateOnLaunch() {
        settings.activateOnLaunch.toggle()
    }

    @objc private func toggleDisplaySleep() {
        settings.preventDisplaySleep.toggle()
        preventer.preventDisplaySleep = settings.preventDisplaySleep
        // Re-take the assertion with the new type if currently active.
        if case .awake(let until) = controller.state {
            let duration: Duration
            if let until {
                duration = .minutes(max(1, Int(until.timeIntervalSinceNow / 60)))
            } else {
                duration = .indefinite
            }
            controller.deactivate()
            controller.activate(for: duration)
        }
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("Launch at login failed: \(error)")
        }
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = MenuBarPresenter.appName
        alert.informativeText = "Keeps your Mac awake.\n\nLeft-click the icon to toggle, right-click for durations and preferences."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
