using Toybox.WatchUi;

// Handles the stop menu (opened by START/STOP while recording):
// Resume / Change speed / Save / Discard.
class SessionMenuDelegate extends WatchUi.Menu2InputDelegate {

    private var _main;
    private var _tracker;

    function initialize(main, tracker) {
        Menu2InputDelegate.initialize();
        _main = main;
        _tracker = tracker;
    }

    function onSelect(item) {
        var id = item.getId();
        WatchUi.popView(WatchUi.SLIDE_DOWN);

        if (id == :resume) {
            _tracker.resume();
        } else if (id == :speed) {
            // BACK on the picker leaves the session paused; START resumes.
            _main.pickSpeed(_main.method(:onChangeSpeed), null);
        } else if (id == :save) {
            _main.pickDistance();
        } else { // :discard
            _tracker.discard();
        }
        WatchUi.requestUpdate();
    }

    // Backing out of the stop menu resumes (native behavior).
    function onBack() {
        _tracker.resume();
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}
