using Toybox.WatchUi;

// Settings menu (hold UP on the splash): steps per minute, default speed.
class SettingsMenuDelegate extends WatchUi.Menu2InputDelegate {

    private var _main;

    function initialize(main) {
        Menu2InputDelegate.initialize();
        _main = main;
    }

    function onSelect(item) {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        if (item.getId() == :cadence) {
            _main.pickCadence();
        } else {
            _main.pickSpeed(_main.method(:onSettingsSpeed), null);
        }
    }
}
