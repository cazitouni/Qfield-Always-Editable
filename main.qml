import QtQuick
import org.qfield
import org.qgis

Item {
    id: plugin

    property bool showToast: false
    property var featureForm: iface.findItemByObjectName("featureForm")
    property var pointHandler: iface.findItemByObjectName("pointHandler")
    property string lastState: ""

    function switchToEdit() {
        if (!featureForm ||
            featureForm.state !== "FeatureForm") {
            return
        }
        var layer = featureForm.selection
            ? featureForm.selection.focusedLayer
            : null
        if (layer && layer.readOnly)
            return
        featureForm.state = "FeatureFormEdit"
        iface.logMessage(
            "Always Editable: switched feature form to edit mode"
        )
    }

    function findInnerForm(item, depth) {
        if (!item || depth > 10)
            return null
        if (typeof item.confirm === "function" &&
            item.model !== undefined) {
            return item
        }
        var kids = item.children
        if (kids) {
            for (var i = 0; i < kids.length; i++) {
                var found = findInnerForm(kids[i], depth + 1)

                if (found)
                    return found
            }
        }
        return null
    }

    function validateAndClose() {
        if (!featureForm) {
            iface.logMessage(
                "Always Editable: featureForm not found"
            )
            return
        }
        if (featureForm.state !== "FeatureFormEdit") {
            return
        }
        iface.logMessage(
            "Always Editable: canvas click -> validate form"
        )
        var inner = findInnerForm(featureForm, 0)
        if (!inner) {
            iface.logMessage(
                "Always Editable: inner feature form not found"
            )
            return
        }
        if (inner.model &&
            inner.model.constraintsHardValid === false) {
            iface.mainWindow().displayToast(
                qsTr("Please fix the invalid fields before closing")
            )
            return
        }
        inner.confirm()
        iface.logMessage(
            "Always Editable: feature confirmed"
        )
        Qt.callLater(function() {
            if (featureForm) {
                featureForm.state = "Hidden"
                iface.logMessage(
                    "Always Editable: feature form closed"
                )
            }
        })
    }

    function registerPointHandler() {
        pointHandler = iface.findItemByObjectName("pointHandler")
        if (!pointHandler) {
            iface.logMessage(
                "Always Editable: pointHandler NOT FOUND"
            )
            return
        }
        pointHandler.registerHandler(
            "alwaysEditableSave",
            function(point, type, interactionType) {
                if (interactionType !== "clicked")
                    return false
                if (!plugin.featureForm)
                    return false
                if (plugin.featureForm.state !== "FeatureFormEdit")
                    return false
                iface.logMessage(
                    "Always Editable: pointHandler click detected"
                )
                plugin.validateAndClose()
                return true
            }
        )
        iface.logMessage(
            "Always Editable: point handler registered"
        )
    }

    Connections {
        target: plugin.featureForm
        function onStateChanged() {
            if (!plugin.featureForm)
                return
            var previous = plugin.lastState
            plugin.lastState = plugin.featureForm.state
            if (plugin.lastState === "FeatureForm" &&
                previous !== "FeatureFormEdit") {

                Qt.callLater(function() {
                    plugin.switchToEdit()
                })
            }
        }
    }

    Connections {
        target: iface
        function onLoadProjectEnded(path, name) {
            Qt.callLater(function() {
                plugin.registerPointHandler()
            })
        }
    }

    Component.onCompleted: {
        plugin.unlockLayers()
        if (plugin.featureForm) {
            plugin.lastState = plugin.featureForm.state
        } else {
            iface.logMessage(
                "Always Editable: featureForm item not found"
            )
        }
        plugin.registerPointHandler()
    }

    Component.onDestruction: {
        if (plugin.pointHandler) {
            try {
                plugin.pointHandler.deregisterHandler(
                    "alwaysEditableSave"
                )
            } catch (e) {
                iface.logMessage(
                    "Always Editable: failed to deregister point handler: " + e
                )
            }
        }
    }
}