using Toybox.WatchUi;

// Button handling, modeled on the native FR255 activity controls.
//
//   START/STOP -> onSelect : splash -> speed picker -> record;
//                            recording -> pause + stop menu; paused -> resume
//   BACK       -> onBack   : exit on splash; swallowed while a session exists
//   UP / DOWN  -> cycle data pages
//   MENU (hold UP) on splash -> settings (steps/min, default speed)
//
// Also owns the picker callbacks so the menus can reach them.
class WalkingPadDelegate extends WatchUi.BehaviorDelegate {

    // Picker ranges, in picker units.
    const SPEED_MIN = 5;       // 0.5 mph (tenths)
    const SPEED_MAX = 40;      // 4.0 mph
    const CADENCE_MIN = 40;
    const CADENCE_MAX = 160;
    const DIST_MAX = 9999;     // 99.99 mi (hundredths)

    private var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() {
        var t = _view.tracker;
        if (!t.hasSession()) {
            pickSpeed(method(:onStartSpeed), null);
        } else if (t.isRecording()) {
            t.pause();
            _openStopMenu();
        } else {
            t.resume();
        }
        WatchUi.requestUpdate();
        return true;
    }

    function onNextPage() {
        if (_view.tracker.hasSession()) { _view.nextPage(); }
        return true;
    }

    function onPreviousPage() {
        if (_view.tracker.hasSession()) { _view.prevPage(); }
        return true;
    }

    function onBack() {
        return _view.tracker.hasSession();   // false on splash -> exit app
    }

    function onMenu() {
        if (_view.tracker.hasSession()) {
            return true;
        }
        var t = _view.tracker;
        var menu = new WatchUi.Menu2({ :title => "Settings" });
        menu.addItem(new WatchUi.MenuItem("Steps / min",
            t.cadence.toString(), :cadence, {}));
        menu.addItem(new WatchUi.MenuItem("Default speed",
            NumberPickerView.format(t.speedTenths, 1) + " mph", :speed, {}));
        WatchUi.pushView(menu, new SettingsMenuDelegate(self), WatchUi.SLIDE_UP);
        return true;
    }

    // ================= pickers + callbacks =================

    function pickSpeed(onConfirm, onCancel) {
        pushNumberPicker("Treadmill speed", _view.tracker.speedTenths, "mph", 1,
            1, SPEED_MIN, SPEED_MAX, onConfirm, onCancel);
    }

    function pickCadence() {
        pushNumberPicker("Steps / min", _view.tracker.cadence, "spm", 0,
            1, CADENCE_MIN, CADENCE_MAX, method(:onCadence), null);
    }

    // Prefilled with the estimate; adjust to match the treadmill display.
    function pickDistance() {
        pushNumberPicker("Treadmill dist", _view.tracker.distanceHundredths(), "mi", 2,
            1, 0, DIST_MAX, method(:onDistance), method(:onDistanceSkip));
    }

    function onStartSpeed(v) {
        _view.tracker.setSpeedTenths(v);
        _view.page = 0;
        _view.tracker.start();
        WatchUi.requestUpdate();
    }

    // Speed changed from the stop menu: keep totals, carry on walking.
    function onChangeSpeed(v) {
        _view.tracker.setSpeedTenths(v);
        _view.tracker.resume();
        WatchUi.requestUpdate();
    }

    function onSettingsSpeed(v) {
        _view.tracker.setSpeedTenths(v);
    }

    function onCadence(v) {
        _view.tracker.setCadence(v);
    }

    function onDistance(v) {
        _view.tracker.saveAndEnd(v);
        WatchUi.requestUpdate();
    }

    // BACK on the distance picker saves with the estimated distance.
    function onDistanceSkip() {
        onDistance(_view.tracker.distanceHundredths());
    }

    // Native-style stop menu: Resume first (so START selects it).
    function _openStopMenu() {
        var menu = new WatchUi.Menu2({ :title => "Walking Pad" });
        menu.addItem(new WatchUi.MenuItem("Resume", null, :resume, {}));
        menu.addItem(new WatchUi.MenuItem("Change speed",
            NumberPickerView.format(_view.tracker.speedTenths, 1) + " mph", :speed, {}));
        menu.addItem(new WatchUi.MenuItem("Save", null, :save, {}));
        menu.addItem(new WatchUi.MenuItem("Discard", null, :discard, {}));
        WatchUi.pushView(menu, new SessionMenuDelegate(self, _view.tracker), WatchUi.SLIDE_UP);
    }
}
