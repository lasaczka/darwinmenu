import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts
import org.kde.draganddrop 2.0 as DragDrop
import org.kde.iconthemes as KIconThemes
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami 2.20 as Kirigami
import org.kde.ksvg 1.0 as KSvg
import org.kde.plasma.plasmoid 2.0
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: configGeneral

    property bool cfg_useRectangleButtonShape: Plasmoid.configuration.useRectangleButtonShape
    property string cfg_icon: Plasmoid.configuration.icon
    property bool cfg_useFixedIconSize: Plasmoid.configuration.useFixedIconSize
    property int cfg_iconSizePercent: iconSizePercent.value
    property int cfg_fixedIconSize: Plasmoid.configuration.fixedIconSize
    property bool cfg_useCustomButtonImage: Plasmoid.configuration.useCustomButtonImage
    property string cfg_customButtonImage: Plasmoid.configuration.customButtonImage
    property bool cfg_resizeIconToRoot: resizeIconToRoot.checked
    property bool cfg_showMenuItemIcons: Plasmoid.configuration.showMenuItemIcons
    property bool cfg_usePowerDialog: Plasmoid.configuration.usePowerDialog
    property int cfg_powerDialogCountdown: Plasmoid.configuration.powerDialogCountdown
    property bool cfg_quickAction: Plasmoid.configuration.quickAction
    property string cgf_quickActionModifier: Plasmoid.configuration.quickActionModifier

    property bool cfg_shortcutOpensPlasmoid: Plasmoid.configuration.shortcutOpensPlasmoid
    property bool cfg_aboutThisPCUseCommand: Plasmoid.configuration.aboutThisPCUseCommand

    property alias cfg_aboutThisPCCommand: aboutThisPCCommand.text
    property alias cfg_appStoreCommand: appStoreCommand.text

    Kirigami.FormLayout {
        anchors.left: parent.left
        anchors.right: parent.right

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Main")
        }
        Item {
            Kirigami.FormData.isSection: false
        }

        ComboBox {
            id: useRectangleButtonShape
            currentIndex: configGeneral.cfg_useRectangleButtonShape ? 0 : 1
            Kirigami.FormData.label: i18n("Button shape")
            model: [i18n("Rectangle"),
                    i18n("Square")]
            //use separate lines so extract.rb be able to capture both
            onCurrentIndexChanged: {
                configGeneral.cfg_useRectangleButtonShape = model[currentIndex] === i18n("Rectangle")
            }
        }

        Item {
            Kirigami.FormData.isSection: false
        }

        ComboBox {
            id: globalShortcutAction
            currentIndex: configGeneral.cfg_shortcutOpensPlasmoid ? 1 : 0
            Kirigami.FormData.label: i18n("Global shortcut opens:")
            model: [i18nc("force quit action", "Force Quit"), i18n("Plasmoid")]

            onCurrentIndexChanged: {
                configGeneral.cfg_shortcutOpensPlasmoid = model[currentIndex] === i18n("Plasmoid")
            }
        }

        CheckBox {
            Kirigami.FormData.label: i18n("Menu items")
            text: i18n("Show icons next to menu items")
            checked: configGeneral.cfg_showMenuItemIcons
            onToggled: configGeneral.cfg_showMenuItemIcons = checked
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Power Actions")
        }

        CheckBox {
            Kirigami.FormData.label: i18n("Power Dialog")
            text: i18n("Use dialog box instead of lockscreen")
            checked: configGeneral.cfg_usePowerDialog
            onToggled: configGeneral.cfg_usePowerDialog = checked
        }

        SpinBox {
            visible: configGeneral.cfg_usePowerDialog
            Kirigami.FormData.label: i18n("Countdown Time")
            from: 5
            to: 60
            value: configGeneral.cfg_powerDialogCountdown
            onValueChanged: configGeneral.cfg_powerDialogCountdown = value
        }

        CheckBox {
            Kirigami.FormData.label: i18n("Quick action")
            text: i18n("Skip confirmation when Action key is pressed")
            checked: configGeneral.cfg_quickAction
            onToggled: configGeneral.cfg_quickAction = checked
        }

        Kirigami.ActionTextField {
            id: quickActionModifier
            visible: configGeneral.cfg_quickAction
            Kirigami.FormData.label: i18n("Quick action shortcut")
            text: Plasmoid.configuration.quickActionModifier ?? "Ctrl+Space"
            placeholderText: "Ctrl+Space"
            onTextEdited: {
                configGeneral.cfg_quickActionModifier = quickActionModifier.text
            }
            rightActions: [
                Action {
                    icon.name: "edit-clear"
                    enabled: quickActionModifier.text !== ""
                    text: i18n("Clear field")
                    onTriggered: {
                        quickActionModifier.clear()
                        configGeneral.cfg_quickActionModifier = ""
                    }
                },
                Action {
                    icon.name: "edit-reset"
                    text: i18n("Reset default")
                    onTriggered: {
                        quickActionModifier.text = Plasmoid.configuration.quickActionModifierDefault
                        configGeneral.cfg_quickActionModifier = Plasmoid.configuration.quickActionModifierDefault
                    }
                }
            ]
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Icon")
        }

        Item {
            Kirigami.FormData.isSection: false
        }

        Button {
            id: iconButton

            Kirigami.FormData.label: i18n("Icon")

            implicitWidth: previewFrame.width + Kirigami.Units.smallSpacing * 2
            implicitHeight: previewFrame.height + Kirigami.Units.smallSpacing * 2

            // Just to provide some visual feedback when dragging;
            // cannot have checked without checkable enabled
            checkable: true
            checked: dropArea.containsAcceptableDrag

            onPressed: iconMenu.opened ? iconMenu.close() : iconMenu.open()

            DragDrop.DropArea {
                id: dropArea

                property bool containsAcceptableDrag: false

                anchors.fill: parent

                onDragEnter: {
                    // Cannot use string operations (e.g. indexOf()) on "url" basic type.
                    var urlString = event.mimeData.url.toString();

                    // This list is also hardcoded in KIconDialog.
                    var extensions = [".png", ".xpm", ".svg", ".svgz"];
                    containsAcceptableDrag = urlString.indexOf("file:///") === 0 && extensions.some(function (extension) {
                        return urlString.indexOf(extension) === urlString.length - extension.length; // "endsWith"
                    });

                    if (!containsAcceptableDrag) {
                        event.ignore();
                    }
                }
                onDragLeave: containsAcceptableDrag = false

                onDrop: {
                    if (containsAcceptableDrag) {
                        // Strip file:// prefix, we already verified in onDragEnter that we have only local URLs.
                        iconDialog.setCustomButtonImage(event.mimeData.url.toString().substr("file://".length));
                    }
                    containsAcceptableDrag = false;
                }
            }

            KIconThemes.IconDialog {
                id: iconDialog

                function setCustomButtonImage(image) {
                    configGeneral.cfg_customButtonImage = image || configGeneral.cfg_icon || "start-here-kde-symbolic"
                    configGeneral.cfg_useCustomButtonImage = true;
                }

                onIconNameChanged: setCustomButtonImage(iconName);
            }

            KSvg.FrameSvgItem {
                id: previewFrame
                anchors.centerIn: parent
                imagePath: Plasmoid.location === PlasmaCore.Types.Vertical || Plasmoid.location === PlasmaCore.Types.Horizontal
                    ? "widgets/panel-background" : "widgets/background"
                width: Kirigami.Units.iconSizes.large + fixedMargins.left + fixedMargins.right
                height: Kirigami.Units.iconSizes.large + fixedMargins.top + fixedMargins.bottom

                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: Kirigami.Units.iconSizes.large
                    height: width
                    source: configGeneral.cfg_useCustomButtonImage ? configGeneral.cfg_customButtonImage : configGeneral.cfg_icon
                }
            }

            Menu {
                id: iconMenu

                // Appear below the button
                y: +parent.height

                onClosed: iconButton.checked = false;

                MenuItem {
                    text: i18nc("@item:inmenu Open icon chooser dialog", "Choose…")
                    icon.name: "document-open-folder"
                    onClicked: iconDialog.open()
                }
                MenuItem {
                    text: i18nc("@item:inmenu Reset icon to default", "Clear Icon")
                    icon.name: "edit-clear"
                    onClicked: {
                        configGeneral.cfg_icon = "start-here-kde-symbolic"
                        configGeneral.cfg_useCustomButtonImage = false
                    }
                }
            }
        }

        Item {
            Kirigami.FormData.isSection: false
        }

        ComboBox {
            id: iconSizeCalculationMethod
            currentIndex: configGeneral.cfg_useFixedIconSize ? 1 : 0
            Kirigami.FormData.label: i18n("Icon size")
            model: [i18n("Relative"), i18n("Fixed")]

            onCurrentIndexChanged: {
                configGeneral.cfg_useFixedIconSize = model[currentIndex] === i18n("Fixed")
            }
        }

        Item {
            Kirigami.FormData.isSection: false
        }

        Slider {
            visible: !configGeneral.cfg_useFixedIconSize
            anchors.left: iconSizeCalculationMethod.left
            anchors.right: iconSizeCalculationMethod.right
            id: iconSizePercent
            orientation: Qt.Horizontal
            value: Plasmoid.configuration.iconSizePercent
            from: 1
            to: 100
            stepSize: 1
            onValueChanged: {
                configGeneral.cfg_iconSizePercent = iconSizePercent.value
                iconSizePercentSpinBox.value = iconSizePercent.value
            }
        }

        SpinBox {
            visible: !configGeneral.cfg_useFixedIconSize
            anchors.left: iconSizePercent.right
            anchors.leftMargin: 10
            anchors.rightMargin: 60
            anchors.right: appStoreCommand.right
            anchors.verticalCenter: iconSizePercent.verticalCenter
            id: iconSizePercentSpinBox
            from: 1
            value: configGeneral.cfg_iconSizePercent
            to: 100
            stepSize: 1
            editable: true
            onValueChanged: {
                configGeneral.cfg_iconSizePercent = iconSizePercentSpinBox.value
                iconSizePercent.value = iconSizePercentSpinBox.value
            }
        }

        SpinBox {
            visible: configGeneral.cfg_useFixedIconSize
            anchors.left: iconSizeCalculationMethod.left
            anchors.right: iconSizeCalculationMethod.right
            id: fixedIconSize
            from: 1
            to: 2000
            value: configGeneral.cfg_fixedIconSize
            stepSize: 1
            editable: true
            onValueChanged: {
                configGeneral.cfg_fixedIconSize = fixedIconSize.value
            }
        }

        Item {
            visible: configGeneral.cfg_useFixedIconSize
            Kirigami.FormData.isSection: false
        }

        Button {
            visible: configGeneral.cfg_useFixedIconSize
            id: iconSizePreviewButton
            text: i18n("Preview icon size")
            icon.name: "dialog-icon-preview-symbolic"
            onClicked: {
                iconSizePreviewPopup.open()
            }
        }

        Item {
            visible: configGeneral.cfg_useFixedIconSize
            Kirigami.FormData.isSection: false
        }

        Switch {
            visible: configGeneral.cfg_useFixedIconSize
            id: resizeIconToRoot
            Kirigami.FormData.label: i18n("Fit to root element")
            checked: Plasmoid.configuration.resizeIconToRoot
            onClicked: {
                configGeneral.cfg_resizeIconToRoot = resizeIconToRoot.checked
            }
        }
        Popup {
            id: iconSizePreviewPopup
            x: iconSizePreviewButton.x - iconSizePreviewPopup.width - 20
            y: fixedIconSize.y
            width: 50
            height: 50
            modal: true
            focus: true

            Kirigami.Icon {
                id: menuIcon
                anchors.centerIn: parent
                source: configGeneral.cfg_useCustomButtonImage ? configGeneral.cfg_customButtonImage : configGeneral.cfg_icon
                height: {
                    if (configGeneral.cfg_resizeIconToRoot) {
                        return configGeneral.cfg_fixedIconSize > iconSizePreviewPopup.height
                            ? iconSizePreviewPopup.height
                            : configGeneral.cfg_fixedIconSize
                    }
                    return configGeneral.cfg_fixedIconSize
                }
                width: height
            }
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Override actions")
        }

        Item {
            Kirigami.FormData.isSection: false
        }

        ComboBox {
            id: aboutThisPCActions
            currentIndex: configGeneral.cfg_aboutThisPCUseCommand ? 1 : 0
            Kirigami.FormData.label: i18n("About This PC action")
            model: [i18n("System"), i18n("Command")]

            onCurrentIndexChanged: {
                configGeneral.cfg_aboutThisPCUseCommand = model[currentIndex] === i18n("Command")
            }
        }

        Item {
            Kirigami.FormData.isSection: false
        }

        Kirigami.ActionTextField {
            id: aboutThisPCCommand
            visible: configGeneral.cfg_aboutThisPCUseCommand
            Kirigami.FormData.label: i18n("About this PC command")
            text: Plasmoid.configuration.aboutThisPCCommand ?? ""
            placeholderText: i18n("Type here to override command")
            onTextEdited: {
                configGeneral.cfg_aaboutThisPCCommand = aboutThisPCCommand.text
            }
            rightActions: [
                Action {
                    icon.name: "edit-clear"
                    enabled: aboutThisPCCommand.text !== ""
                    text: i18n("Clear field")
                    onTriggered: {
                        aboutThisPCCommand.clear()
                        configGeneral.cfg_aboutThisPCCommand = ""
                    }
                },
                Action {
                    icon.name: "edit-reset"
                    text: i18n("Reset default")
                    onTriggered: {
                        aboutThisPCCommand.text = Plasmoid.configuration.aboutThisPCCommandDefault
                        configGeneral.cfg_aboutThisPCCommand = Plasmoid.configuration.aboutThisPCCommandDefault
                    }
                }
            ]
        }

        Item {
            Kirigami.FormData.isSection: false
        }

        Kirigami.ActionTextField {
            id: appStoreCommand
            Kirigami.FormData.label: i18n("App Store command")
            text: Plasmoid.configuration.appStoreCommand ?? ""
            placeholderText: i18n("Type here to override command")
            onTextEdited: {
                configGeneral.cfg_appStoreCommand = appStoreCommand.text
            }
            rightActions: [
                Action {
                    icon.name: "edit-clear"
                    enabled: appStoreCommand.text !== ""
                    text: i18n("Clear field")
                    onTriggered: {
                        appStoreCommand.clear()
                        configGeneral.cfg_appStoreCommand = ""
                    }
                },
                Action {
                    icon.name: "edit-reset"
                    text: i18n("Reset default")
                    onTriggered: {
                        appStoreCommand.text = Plasmoid.configuration.appStoreCommandDefault
                        configGeneral.cfg_appStoreCommand = Plasmoid.configuration.appStoreCommandDefault
                    }
                }
            ]
        }
    }
}
