using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Math;

// A simple button-driven number picker: UP increases, DOWN decreases,
// START confirms, BACK cancels. Values are integers (e.g. tenths of a mph);
// `decimals` sets how many of the low digits are shown after the point.
//
// On confirm/cancel the picker pops itself, then invokes the callback, so a
// callback is free to push the next view.
class NumberPickerView extends WatchUi.View {

    public var value;
    private var _title;
    private var _units;
    private var _decimals;

    function initialize(title, value, units, decimals) {
        View.initialize();
        _title = title;
        self.value = value;
        _units = units;
        _decimals = decimals;
    }

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (h * 0.22).toNumber(), Graphics.FONT_SMALL, _title,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Up/down hint arrows on the left, next to the FR255's UP/DOWN buttons.
        var ax = (w * 0.12).toNumber();
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[ax, h / 2 - 34], [ax - 8, h / 2 - 22], [ax + 8, h / 2 - 22]]);
        dc.fillPolygon([[ax, h / 2 + 34], [ax - 8, h / 2 + 22], [ax + 8, h / 2 + 22]]);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h / 2, Graphics.FONT_NUMBER_HOT, format(value, _decimals),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (h * 0.72).toNumber(), Graphics.FONT_SMALL, _units,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (h * 0.85).toNumber(), Graphics.FONT_XTINY, "START to confirm",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Integer with implied decimals -> display string (18, 1 -> "1.8").
    static function format(v, decimals) {
        if (decimals == 0) {
            return v.toString();
        }
        var div = Math.pow(10, decimals).toNumber();
        return (v.toFloat() / div).format("%." + decimals + "f");
    }
}

class NumberPickerDelegate extends WatchUi.BehaviorDelegate {

    private var _view;
    private var _step;
    private var _min;
    private var _max;
    private var _onConfirm;   // Method(value)
    private var _onCancel;    // Method() or null

    function initialize(view, step, min, max, onConfirm, onCancel) {
        BehaviorDelegate.initialize();
        _view = view;
        _step = step;
        _min = min;
        _max = max;
        _onConfirm = onConfirm;
        _onCancel = onCancel;
    }

    // UP
    function onPreviousPage() {
        _adjust(_step);
        return true;
    }

    // DOWN
    function onNextPage() {
        _adjust(-_step);
        return true;
    }

    // START
    function onSelect() {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        _onConfirm.invoke(_view.value);
        return true;
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        if (_onCancel != null) {
            _onCancel.invoke();
        }
        return true;
    }

    private function _adjust(delta) {
        var v = _view.value + delta;
        if (v < _min) { v = _min; }
        if (v > _max) { v = _max; }
        _view.value = v;
        WatchUi.requestUpdate();
    }
}

// Push a picker. Kept as a module function so callers stay one-liners.
function pushNumberPicker(title, value, units, decimals, step, min, max, onConfirm, onCancel) {
    var view = new NumberPickerView(title, value, units, decimals);
    WatchUi.pushView(view,
        new NumberPickerDelegate(view, step, min, max, onConfirm, onCancel),
        WatchUi.SLIDE_UP);
}
