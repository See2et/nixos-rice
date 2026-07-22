import QtQuick
import Quickshell
import qs.Services
import "EmojiData.js" as EmojiData

Item {
    id: root

    property var pluginService: null
    property string trigger: ":"

    signal itemsChanged()

    function getItems(query) {
        return EmojiData.getItems(query)
    }

    function executeItem(item) {
        const emoji = item.emoji || item.action.split(":").slice(1).join(":")
        Quickshell.execDetached(["dms", "cl", "copy", emoji])
        ToastService.showInfo("Copied " + emoji + " to clipboard")
    }
}
