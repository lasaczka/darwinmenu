import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt.labs.platform as QtLabs
import org.kde.kcmutils
import org.kde.plasma.plasmoid
import org.kde.ksvg 1.0 as KSvg
import org.kde.kirigami 2 as Kirigami
import org.kde.coreaddons as KCoreAddons
import org.kde.plasma.private.sessions 2.0 as Sessions
import org.kde.taskmanager 0.1 as TaskManager
import org.kde.plasma.plasma5support as Plasma5Support

AbstractButton {
    id: menuButton

    focus: true

    readonly property string appStoreCommand: Plasmoid.configuration.appStoreCommand
        ?? Plasmoid.configuration.appStoreCommandDefault
    readonly property string aboutThisPCCommand: Plasmoid.configuration.aboutThisPCCommand
        ?? Plasmoid.configuration.aboutThisPCCommandDefault
    readonly property bool aboutThisPCUseCommand: Plasmoid.configuration.aboutThisPCUseCommand
        ?? Plasmoid.configuration.aboutThisPCUseCommandDefault

    readonly property var customCommandsConfig: Plasmoid.configuration.commands
    readonly property bool customCommandsInSeparateMenu: Plasmoid.configuration.customCommandsInSeparateMenu
        ?? Plasmoid.configuration.customCommandsInSeparateMenuDefault
    readonly property string customCommandsMenuTitle: Plasmoid.configuration.customCommandsMenuTitle ?? ""
    readonly property bool showMenuItemIcons: Plasmoid.configuration.showMenuItemIcons ?? false
    readonly property bool showCustomCommandIcons: Plasmoid.configuration.showCustomCommandIcons ?? true
    readonly property string defaultCustomCommandIcon: Plasmoid.configuration.defaultCustomCommandIcon ?? "utilities-terminal"
    readonly property bool usePowerDialog: Plasmoid.configuration.usePowerDialog ?? false
    readonly property bool quickAction: Plasmoid.configuration.quickAction ?? false
    readonly property string quickActionKeys: Plasmoid.configuration.quickActionModifier ?? "Ctrl+Space"
    readonly property string ellipsis: "\u2026"
    readonly property string ellipsisPlaceholder: "\u2007"

    property var customCommands: []
    property bool actionKeyPressed : false

    function reloadCustomCommands() {
        const commands = []

        for (const rawCommand of (Plasmoid.configuration.commands ?? [])) {
            try {
                const command = JSON.parse(rawCommand)
                const text = (command.text ?? "").trim()
                const executable = (command.command ?? "").trim()

                if (text.length === 0 && executable.length === 0) {
                    continue
                }

                commands.push(command)
            } catch (error) {
            }
        }

        customCommands = commands
    }

    function customCommandIcon(iconName) {
        if (!showMenuItemIcons || !showCustomCommandIcons) {
            return ""
        }

        return iconName?.length > 0
            ? iconName
            : (defaultCustomCommandIcon?.length > 0 ? defaultCustomCommandIcon : "utilities-terminal")
    }

    // QtLabs.MenuItem renders native menus outside the QML tree so once opened, ellipsis value doesn't bind and it's not longer evaluated again.
    // So the Keys.onPressed approach works but has not visual feedback which leads to user confusion.
    // The toggle solution using hidden QtLabs.MenuItem instead works because run as native menu.
    //
    //Keys.onPressed: function (event) {
    //    if (!menuButton.quickAction || !menu.isOpened) return
    //    if (event.key === Qt.Key_Space && (event.modifiers & Qt.ControlModifier)){
    //        if (!event.isAutoRepeat){
    //            menuButton.actionKeyPressed = !menuButton.actionKeyPressed
    //            ellipsis = "\u2007"
    //        }
    //        event.accepted = true
    //    }
    //}

    RecentItems {
        id: recentItems
    }

    enum State {
        Rest,
        Hover,
        Down
    }

    property int menuState: {
        if (down) {
            return MainMenuButton.State.Down;
        } else if (hovered && !menu.isOpened) {
            return MainMenuButton.State.Hover;
        }
        return MainMenuButton.State.Rest;
    }

    Connections {
        target: Plasmoid
        function onActivated() {
            Plasmoid.configuration.shortcutOpensPlasmoid
                ? menuButton.clicked()
                : forceQuit.show()
        }
    }

    Sessions.SessionManagement {
        id: sm
    }

    TaskManager.TasksModel {
        id: tasksModel
    }

    KCoreAddons.KUser {
        id: kUser
    }

    onCustomCommandsConfigChanged: reloadCustomCommands()
    Component.onCompleted: reloadCustomCommands()

    onCustomCommandsChanged: {
        customMenuEntries.clear()
        for (const command of customCommands) {
            customMenuEntries.append(command)
        }
    }

    onClicked: {
        menu.isOpened ? menu.close() : menu.open(root)
    }

    Layout.preferredHeight: root.height
    Layout.preferredWidth: Plasmoid.configuration.useRectangleButtonShape
        ? Layout.preferredHeight * 1.5
        : Layout.preferredHeight

    contentItem: Item {
        width: parent.width
        height: parent.height
        Kirigami.Icon {
            id: menuIcon
            anchors.centerIn: parent
            source: root.icon
            height: {
                if (Plasmoid.configuration.useFixedIconSize) {
                    if (Plasmoid.configuration.resizeIconToRoot) {
                        return Plasmoid.configuration.fixedIconSize > root.height
                            ? root.height
                            : Plasmoid.configuration.fixedIconSize
                    }
                    return Plasmoid.configuration.fixedIconSize
                }
                return parent.height * (Plasmoid.configuration.iconSizePercent / 100)
            }
            width: height
        }
    }

    down: menu.isOpened

    background: KSvg.FrameSvgItem {
        id: rest
        height: parent.height
        width: parent.width
        imagePath: "widgets/menubaritem"
        prefix: switch (menuButton.menuState) {
            case MainMenuButton.State.Down: return "pressed";
            case MainMenuButton.State.Hover: return "hover";
            case MainMenuButton.State.Rest: return "normal";
        }
    }

    QtLabs.Menu {
        id: menu
        property bool isOpened: false
        readonly property int customCommandsEntryStartIndex: 4

        QtLabs.MenuItem {
            visible: false
            shortcut: quickActionKeys
            enabled: menu.isOpened & menuButton.quickAction
            onTriggered: {
                menuButton.actionKeyPressed = !menuButton.actionKeyPressed
            }
        }

        QtLabs.MenuItem {
            id: aboutThisPCMenuItem
            visible: Plasmoid.configuration.showAboutThisPCButton
            text: i18n("About this PC")
            icon.name: menuButton.showMenuItemIcons ? "computer-laptop" : ""
            onTriggered: menuButton.aboutThisPCUseCommand
                ? executable.exec(menuButton.aboutThisPCCommand)
                : executable.exec("kcmshell6 kcm_about-distro")
        }

        QtLabs.MenuSeparator {
            visible: Plasmoid.configuration.showAboutThisPCButton
        }

        QtLabs.Menu {
            id: recentItemsMenu
            title: i18n("Recent Items")
            icon.name: menuButton.showMenuItemIcons ? "clock" : ""

            Instantiator {
                model: recentItems.recentDocs
                delegate: QtLabs.MenuItem {
                    text: modelData.name
                    icon.name: menuButton.showMenuItemIcons ? modelData.icon : ""
                    onTriggered: Qt.openUrlExternally(modelData.url)
                }

                onObjectAdded: (index, object) => recentItemsMenu.insertItem(index, object)
                onObjectRemoved: (index, object) => recentItemsMenu.removeItem(object)
            }

            QtLabs.MenuSeparator {
                visible: recentItems.recentDocs.length > 0
            }

            QtLabs.MenuItem {
                text: i18n("Clear Menu")
                visible: recentItems.recentDocs.length > 0
                icon.name: menuButton.showMenuItemIcons ? "edit-clear-history" : ""
                onTriggered: recentItems.clearRecentItems()
            }

            QtLabs.MenuItem {
                text: i18n("Refresh")
                icon.name: menuButton.showMenuItemIcons ? "view-refresh" : ""
                onTriggered: recentItems.loadRecentItems()
            }
        }

        QtLabs.MenuSeparator {}

        ListModel {
            id: customMenuEntries
        }

        QtLabs.Menu {
            id: customCommandsSubMenu
            enabled: menuButton.customCommandsInSeparateMenu && customMenuEntries.count > 0
            visible: menuButton.customCommandsInSeparateMenu
            title: menuButton.customCommandsMenuTitle?.length > 0 ? menuButton.customCommandsMenuTitle : i18n("Commands")
            readonly property int customCommandsEntryStartIndex: 0

            Instantiator {
                model: menuButton.customCommandsInSeparateMenu ? customMenuEntries : []
                active: menuButton.customCommandsInSeparateMenu
                delegate: QtLabs.MenuItem {
                    text: model.text
                    icon.name: menuButton.customCommandIcon(model.icon ?? "")
                    onTriggered: executable.exec(model.command)
                }

                onObjectAdded: (index, object) => customCommandsSubMenu.insertItem(
                    customCommandsSubMenu.customCommandsEntryStartIndex + index,
                    object
                )
                onObjectRemoved: (index, object) => customCommandsSubMenu.removeItem(object)
            }
        }
        Instantiator {
            model: menuButton.customCommandsInSeparateMenu ? [] : customMenuEntries
            active: !menuButton.customCommandsInSeparateMenu
            delegate: QtLabs.MenuItem {
                text: model.text
                icon.name: menuButton.customCommandIcon(model.icon ?? "")
                onTriggered: executable.exec(model.command)
            }

            onObjectAdded: (index, object) => menu.insertItem(menu.customCommandsEntryStartIndex + index, object)
            onObjectRemoved: (index, object) => menu.removeItem(object)
        }

        QtLabs.MenuSeparator {}

        QtLabs.MenuItem {
            id: systemSettingsMenuItem
            visible: Plasmoid.configuration.showSystemSettingsButton
            text: i18n("System Settings...")
            icon.name: menuButton.showMenuItemIcons ? "settings-configure" : ""
            onTriggered: KCMLauncher.openSystemSettings("")
        }

        QtLabs.MenuItem {
            id: appStoreMenuItem
            visible: Plasmoid.configuration.showAppStoreButton
            text: i18n("App Store...")
            icon.name: menuButton.showMenuItemIcons ? "applications-other-symbolic" : ""
            onTriggered: executable.exec(menuButton.appStoreCommand)
        }

        QtLabs.MenuSeparator {}

        QtLabs.MenuItem {
            visible: Plasmoid.configuration.showForceQuitButton
            text: i18n("Force Quit")
            icon.name: menuButton.showMenuItemIcons ? "process-stop-symbolic" : ""
            onTriggered: root.forceQuit.show()
            shortcut: Plasmoid.configuration.shortcutOpensPlasmoid ? null : plasmoid.globalShortcut
        }

        QtLabs.MenuSeparator {}
        
        QtLabs.MenuItem {
            visible: Plasmoid.configuration.showSleepButton && sm.canSuspend
            text: i18n("Sleep")
            icon.name: menuButton.showMenuItemIcons ? "system-suspend" : ""
            onTriggered: sm.suspend()
        }

        QtLabs.MenuItem {
            visible: Plasmoid.configuration.showRestartButton
            text: i18n("Restart") + (menuButton.actionKeyPressed ? menuButton.ellipsisPlaceholder : menuButton.ellipsis)
            icon.name: menuButton.showMenuItemIcons ? "system-reboot" : ""
            onTriggered: {
                if (menuButton.actionKeyPressed){
                    sm.requestReboot(Sessions.SessionManagement.Skip)
                }
                else if (menuButton.usePowerDialog) {
                    root.powerDialog.dialogTitle = i18n("Restart")
                    root.powerDialog.dialogAction = i18n("the computer will restart")
                    root.powerDialog.dialogIcon = "system-reboot"
                    root.powerDialog.dialogMessage = i18n("Are you sure you want to restart you computer now?")
                    root.powerDialog.confirmAction = function(){sm.requestReboot(Sessions.SessionManagement.Skip)}
                    root.powerDialog.show()
                }
                else {
                    sm.requestReboot()
                }
            }
        }

        QtLabs.MenuItem {
            visible: Plasmoid.configuration.showShutdownButton
            text: i18n("Shut Down") + (menuButton.actionKeyPressed ? menuButton.ellipsisPlaceholder : menuButton.ellipsis)
            icon.name: menuButton.showMenuItemIcons ? "system-shutdown" : ""
            onTriggered: {
                if (menuButton.actionKeyPressed){
                    sm.requestShutdown(Sessions.SessionManagement.Skip)
                }
                else if (menuButton.usePowerDialog){
                    root.powerDialog.dialogTitle = i18n("Shut Down")
                    root.powerDialog.dialogAction = i18n("the computer will shut down")
                    root.powerDialog.dialogIcon = "system-shutdown"
                    root.powerDialog.dialogMessage = i18n("Are you sure you want to shut down you computer now?")
                    root.powerDialog.confirmAction = function(){sm.requestShutdown(Sessions.SessionManagement.Skip)}
                    root.powerDialog.show()
                }
                else {
                    sm.requestShutdown()
                }
            }
        }

        QtLabs.MenuSeparator {}

        QtLabs.MenuItem {
            visible: Plasmoid.configuration.showLockScreenButton
            text: i18n("Lock Screen")
            icon.name: menuButton.showMenuItemIcons ? "system-lock-screen" : ""
            shortcut: "Meta+L"
            onTriggered: sm.lock()
        }

        QtLabs.MenuItem {
            visible: Plasmoid.configuration.showLogOutButton
            text: i18n("Log Out %1", kUser.fullName) + (menuButton.actionKeyPressed ? menuButton.ellipsisPlaceholder : menuButton.ellipsis)
            icon.name: menuButton.showMenuItemIcons ? "system-log-out" : ""
            shortcut: "Ctrl+Alt+Delete"
            onTriggered: {
                if (menuButton.actionKeyPressed){
                    sm.requestLogout(Sessions.SessionManagement.Skip)
                }
                else if (menuButton.usePowerDialog){
                    root.powerDialog.dialogTitle = i18n("Log Out")
                    root.powerDialog.dialogAction = i18n("you will be logged out")
                    root.powerDialog.dialogIcon = "system-log-out"
                    root.powerDialog.dialogMessage = i18n("Are you sure you want to quit all applications and log out now?")
                    root.powerDialog.confirmAction = function(){sm.requestLogout(Sessions.SessionManagement.Skip)}
                    root.powerDialog.show()
                }
                else {
                    sm.requestLogout()
                }
            }
        }

        onAboutToHide: {
            menu.isOpened = false
        }
        onAboutToShow: {
            menu.isOpened = true
            menuButton.actionKeyPressed = false
            recentItems.loadRecentItems()
        }
    }

    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []

        property var pendingCallback: null

        function exec(cmd, callback) {
            pendingCallback = callback
            connectSource(cmd)
        }

        onNewData: function(source, data) {
            const exitCode = data["exit code"]

            disconnectSource(source)

            if (pendingCallback) {
                const cb = pendingCallback
                pendingCallback = null

                cb(exitCode === 0)
            }
        }
    }

}
