using Toybox.WatchUi;

// Button handling, modeled on the native FR255 running controls.
//
//   START/STOP -> onSelect : not recording -> start; recording -> pause + stop menu
//   BACK       -> onBack   : LAP (mark/correct a run) while active; exit on splash
//   UP / DOWN  -> onPreviousPage / onNextPage : cycle data pages
//   LIGHT      : left to the system (backlight) — we never capture it
//   Stop menu  : Resume / Save / Discard  (Resume is highlighted, so pressing
//                START again resumes — i.e. START/STOP acts as pause/resume)
class WakesurfDelegate extends WatchUi.BehaviorDelegate {

    private var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() {
        var t = _view.tracker;
        if (!t.hasSession()) {
            t.start();                 // begin recording
        } else if (t.isRecording()) {
            t.pause();                 // pause, then show the stop menu
            _openStopMenu();
        } else {
            t.resume();                // paused with no menu -> resume
        }
        WatchUi.requestUpdate();
        return true;
    }

    function onNextPage() {
        _view.nextPage();
        return true;
    }

    function onPreviousPage() {
        _view.prevPage();
        return true;
    }

    // BACK is the LAP button (like native running): mark/correct a run.
    function onBack() {
        var t = _view.tracker;
        if (t.isRecording()) {
            t.toggleRunManual();
            WatchUi.requestUpdate();
            return true;
        }
        if (t.hasSession()) {
            return true;               // paused: swallow so BACK can't exit mid-session
        }
        return false;                  // splash: allow default (exit app)
    }

    // Native-style stop menu: Resume first (so START selects it), then Save, Discard.
    function _openStopMenu() {
        var menu = new WatchUi.Menu2({ :title => "Wakesurf" });
        menu.addItem(new WatchUi.MenuItem("Resume", null, :resume, {}));
        menu.addItem(new WatchUi.MenuItem("Save", null, :save, {}));
        menu.addItem(new WatchUi.MenuItem("Discard", null, :discard, {}));
        WatchUi.pushView(menu, new SessionMenuDelegate(_view), WatchUi.SLIDE_UP);
    }
}
