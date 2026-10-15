using Toybox.WatchUi;

// Handles the stop menu (opened by START/STOP while recording):
// Resume / Save / Discard.
class SessionMenuDelegate extends WatchUi.Menu2InputDelegate {

    private var _view;

    function initialize(view) {
        Menu2InputDelegate.initialize();
        _view = view;
    }

    function onSelect(item) {
        var id = item.getId();
        var t = _view.tracker;

        if (id == :resume) {
            t.resume();
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        } else if (id == :save) {
            t.saveAndEnd();
            WatchUi.popView(WatchUi.SLIDE_DOWN);   // back to the pre-record home screen
        } else { // :discard
            t.discard();
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        }
    }

    // Backing out of the stop menu resumes (native behavior).
    function onBack() {
        _view.tracker.resume();
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}
