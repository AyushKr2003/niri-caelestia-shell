import Quickshell.Io

JsonObject {
    property bool expire: true
    property string fullscreen: "on"
    property bool openExpanded: false
    property int defaultExpireTimeout: 5000
    /** Fallback popup duration (ms) when the server sends expireTimeout = -1. */
    property int popupTimeout: 7000
    property real clearThreshold: 0.3
    property int expandThreshold: 20
    property bool actionOnClick: false
    property int groupPreviewNum: 3
    property Sizes sizes: Sizes {}

    component Sizes: JsonObject {
        property int width: 400
        property int image: 41
        property int badge: 20
    }
}
