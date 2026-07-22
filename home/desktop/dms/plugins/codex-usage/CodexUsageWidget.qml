pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    property string displayText: "󰚩 --/--"
    property string displayTooltip: "Codex usage unavailable\nClick: toggle usage/reset"
    property string severity: ""
    readonly property string processKey: "codexUsage." + (parentScreen?.name ?? "default")

    function stateColor() {
        if (severity === "critical") {
            return Theme.error
        }
        if (severity === "warning") {
            return Theme.warning
        }
        return Theme.surfaceText
    }

    function applyOutput(stdout, exitCode) {
        if (exitCode !== 0) {
            displayText = "󰚩 --/--"
            displayTooltip = "Codex helper failed\nClick: toggle usage/reset"
            severity = ""
            return
        }

        try {
            const payload = JSON.parse(stdout.trim())
            displayText = payload.text || "󰚩 --/--"
            displayTooltip = payload.tooltip || "Codex usage unavailable"
            severity = payload.class || ""
        } catch (error) {
            displayText = "󰚩 --/--"
            displayTooltip = "Codex helper returned invalid JSON\nClick: toggle usage/reset"
            severity = ""
        }
    }

    function runHelper(args) {
        Proc.runCommand(
            processKey + "." + (args.length > 0 ? args.join(".") : "refresh"),
            ["dms-codex-usage"].concat(args),
            (stdout, exitCode) => applyOutput(stdout, exitCode),
            100
        )
    }

    function refresh() {
        runHelper([])
    }

    function toggleMode() {
        runHelper(["--toggle"])
    }

    pillClickAction: () => toggleMode()

    horizontalBarPill: Component {
        StyledRect {
            width: label.implicitWidth + Theme.spacingM * 2
            height: root.widgetThickness
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHigh

            StyledText {
                id: label
                anchors.centerIn: parent
                text: root.displayText
                color: root.stateColor()
                font.pixelSize: Theme.fontSizeMedium
            }
        }
    }

    verticalBarPill: Component {
        StyledRect {
            width: root.widgetThickness
            height: verticalLabel.implicitWidth + Theme.spacingM * 2
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHigh

            StyledText {
                id: verticalLabel
                anchors.centerIn: parent
                text: root.displayText
                color: root.stateColor()
                font.pixelSize: Theme.fontSizeSmall
                rotation: 90
            }
        }
    }

    Timer {
        interval: 30000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: refresh()
}
