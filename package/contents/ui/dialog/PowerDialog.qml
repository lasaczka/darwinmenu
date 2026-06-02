import QtQuick
import QtQuick.Controls
import org.kde.kirigami 2 as Kirigami
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.plasma5support as Plasma5Support

Window {
    id: "root"
    title: dialogTitle
    width: 480
    height: 180

    SystemPalette {
        id: activePalette;
        colorGroup: SystemPalette.Active
    }
    color: activePalette.window

    visible: false
    modality: Qt.ApplicationModal
    flags: Qt.Dialog | Qt.WindowStaysOnTopHint
    transientParent: null

    property string dialogTitle: ""
    property string dialogMessage: ""
    property string dialogIcon: ""
    property string dialogAction: ""
    property bool autoConfirm: true
    property var confirmAction

    readonly property int countdownTime: Plasmoid.configuration.powerDialogCountdown ?? 30
    property int countdown: countdownTime
    property string defaultSaveSession: Plasmoid.configuration.defaultSaveSession

    onVisibleChanged: {

        if (visible) {
            countdown = countdownTime
            restoreSessionCheck.checked = (defaultSaveSession === "restoreLastSession")
            if (autoConfirm) {
                countdownTimer.start()
            }
        }
        else {
            countdownTimer.stop()
            confirmAction = null
        }
    }

    onActiveChanged: {
        if (!active && countdownTimer.running) {
            countdownTimer.stop()
        }
        else if (active && autoConfirm && countdown > 0){
            countdownTimer.start()
        }
    }

    Plasma5Support.DataSource {
        id: sessionModeReader
        engine: "executable"
        connectedSources: ["kreadconfig6 --file ksmserverrc --group General --key loginMode --default restoreLastSession"]
        onNewData: function(source, data) {
            if (data["exit code"] === 0) {
                console.log(data.stdout.trim())
                root.defaultSaveSession = data.stdout.trim()
            }
        }
    }

    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: function(source, data) {
            disconnectSource(source)
        }
    }

    function executeAction(action) {
        var desiredMode = restoreSessionCheck.checked ? "restoreLastSession" : "emptySession"
        if (desiredMode !== defaultSaveSession) {
            executable.connectSource("kwriteconfig6 --file ksmserverrc --group General --key loginMode " + desiredMode)
        }
        if (action){
            action()
        }
    }

    Timer {
        id: countdownTimer

        interval: 1000
        repeat: true

        onTriggered: {
            countdown--
            if (countdown <= 0) {
                stop()
                const action = confirmAction
                root.hide()
                if (action) {
                    executeAction(action)
                }
            }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 16
        width: root.width - 32

        Row {
            width: parent.width
            spacing: 12

            Kirigami.Icon {
                source: dialogIcon
                width: 64
                height: 64
            }

            Column{
                width: parent.width - 76
                spacing: 12

                Label {
                    width: parent.width
                    text: dialogMessage
                    wrapMode: Text.WordWrap
                }

                Label {
                    width: parent.width
                    text: i18n("If you do nothing, %1 automatically in (%2) seconds.", dialogAction, countdown)
                    wrapMode: Text.WordWrap
                }

                CheckBox {
                    id: restoreSessionCheck
                    text: i18n("Reopen windows when loggin back in")
                }
            }
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 12
            spacing: 8

            Button {
                text: i18n("Cancel")
                highlighted: true
                onClicked: {
                    root.hide()
                }
            }

            Button {
                text: dialogTitle
                onClicked: {
                    countdownTimer.stop()
                    const action = confirmAction
                    root.hide()
                    if (action) {
                        executeAction(action)
                    }
                }
            }
        }
    }
}
