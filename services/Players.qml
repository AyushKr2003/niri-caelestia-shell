pragma Singleton

// import qs.components.misc
import qs.config
import qs.services
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick

Singleton {
    id: root

    readonly property list<MprisPlayer> list: Mpris.players.values
    readonly property MprisPlayer active: manualActive ?? list.find(p => getIdentity(p) === Config.services.defaultPlayer) ?? list[0] ?? null
    property MprisPlayer manualActive

    function getIdentity(player: MprisPlayer): string {
        const alias = Config.services.playerAliases.find(a => a.from === player.identity);
        return alias?.to ?? player.identity;
    }

    Connections {
        target: root.active

        function onTrackChanged(): void {
            if (!Config.utilities.toasts.nowPlaying)
                return;
            if (root.active)
                Toaster.toast(qsTr("Now Playing"), qsTr("%1 - %2").arg(root.active.trackArtist).arg(root.active.trackTitle), "music_note");
        }
    }

    // Niri does not have global shortcuts yet ;).
    // CustomShortcut {
    //     name: "mediaToggle"
    //     description: "Toggle media playback"
    //     onPressed: {
    //         const active = root.active;
    //         if (active && active.canTogglePlaying)
    //             active.togglePlaying();
    //     }
    // }

    // CustomShortcut {
    //     name: "mediaPrev"
    //     description: "Previous track"
    //     onPressed: {
    //         const active = root.active;
    //         if (active && active.canGoPrevious)
    //             active.previous();
    //     }
    // }

    // CustomShortcut {
    //     name: "mediaNext"
    //     description: "Next track"
    //     onPressed: {
    //         const active = root.active;
    //         if (active && active.canGoNext)
    //             active.next();
    //     }
    // }

    // CustomShortcut {
    //     name: "mediaStop"
    //     description: "Stop media playback"
    //     onPressed: root.active?.stop()
    // }

    IpcHandler {
        target: "mpris"

        function getActive(prop: string): string {
            const active = root.active;
            return active ? active[prop] ?? "Invalid property" : "No active player";
        }

        function list(): string {
            return root.list.map(p => root.getIdentity(p)).join("\n");
        }

        function play(): void {
            const active = root.active;
            if (active?.canPlay)
                active.play();
        }

        function pause(): void {
            const active = root.active;
            if (active?.canPause)
                active.pause();
        }

        function playPause(): void {
            const active = root.active;
            if (active?.canTogglePlaying)
                active.togglePlaying();
        }

        function previous(): void {
            const active = root.active;
            if (active?.canGoPrevious)
                active.previous();
        }

        function next(): void {
            const active = root.active;
            if (active?.canGoNext)
                active.next();
        }

        function stop(): void {
            root.active?.stop();
        }
    }
}
