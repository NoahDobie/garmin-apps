using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Activity;
using Toybox.Timer;
using Toybox.Lang;

// The main on-screen view. Owns the PadTracker, ticks it once per second, and
// renders the splash or one of two 4-field data pages plus a status arc.
class WalkingPadView extends WatchUi.View {

    public var tracker;
    public var page = 0;                 // 0 = Main, 1 = Totals
    private const NUM_PAGES = 2;

    private var _timer = null;

    private const M_TO_MI = 1.0 / 1609.344;

    function initialize() {
        View.initialize();
        tracker = new PadTracker();
    }

    function onLayout(dc) {
    }

    // 1 Hz tick while visible. Also runs when returning from a menu/picker —
    // idempotent. Totals use timerTime deltas, so hidden time isn't lost.
    function onShow() {
        if (_timer == null) {
            _timer = new Timer.Timer();
            _timer.start(method(:onTick), 1000, true);
        }
    }

    function onHide() {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
    }

    // Typed as Void to match the Timer callback signature.
    function onTick() as Void {
        tracker.onTick(Activity.getActivityInfo());
        WatchUi.requestUpdate();
    }

    function nextPage() {
        page = (page + 1) % NUM_PAGES;
        WatchUi.requestUpdate();
    }

    function prevPage() {
        page = (page + NUM_PAGES - 1) % NUM_PAGES;
        WatchUi.requestUpdate();
    }

    // ================= rendering =================

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        if (!tracker.hasSession()) {
            _drawSplash(dc);
            return;
        }

        var info = Activity.getActivityInfo();
        _drawStatusArc(dc);
        _drawDividers(dc);
        if (page == 0) {
            _draw4(dc,
                "TIME",  _clock((info != null && info.timerTime != null) ? info.timerTime / 1000 : 0),
                "HR",    _hr(info),
                "STEPS", tracker.steps.toNumber().toString(),
                "MILES", (tracker.distanceM * M_TO_MI).format("%.2f"));
        } else {
            _draw4(dc,
                "CAL",   _cal(info),
                "MPH",   NumberPickerView.format(tracker.speedTenths, 1),
                "SPM",   tracker.cadence.toString(),
                "WATCH", tracker.watchSteps.toString());
        }
    }

    // Pre-record home screen, showing the speed/cadence that will be used.
    function _drawSplash(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var mid = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (h * 0.25).toNumber(), Graphics.FONT_MEDIUM, "WALKING PAD", mid);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (h * 0.42).toNumber(), Graphics.FONT_SMALL,
            NumberPickerView.format(tracker.speedTenths, 1) + " mph   "
                + tracker.cadence + " spm", mid);

        dc.drawText(cx, (h * 0.60).toNumber(), Graphics.FONT_SMALL, "Press START", mid);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (h * 0.76).toNumber(), Graphics.FONT_XTINY, "Hold UP for settings", mid);
    }

    // Thin arc along the top edge: green walking, blue paused.
    function _drawStatusArc(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var walking = tracker.isRecording();

        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }
        dc.setColor(walking ? Graphics.COLOR_GREEN : Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(8);
        dc.drawArc(w / 2, h / 2, (w / 2) - 6, Graphics.ARC_CLOCKWISE, 130, 50);
        dc.setPenWidth(1);
        dc.drawText(w / 2, (h * 0.11).toNumber(), Graphics.FONT_XTINY,
            walking ? "WALKING" : "PAUSED",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // The + separators of the 4-field grid.
    function _drawDividers(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(w / 2, (h * 0.18).toNumber(), w / 2, (h * 0.82).toNumber());
        dc.drawLine((w * 0.16).toNumber(), h / 2, (w * 0.84).toNumber(), h / 2);
    }

    // Lay out four label/value fields in the screen quadrants. Positions are
    // pulled toward center so nothing clips on the round display.
    function _draw4(dc, l1, v1, l2, v2, l3, v3, l4, v4) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var lx = (w * 0.29).toNumber();
        var rx = (w * 0.71).toNumber();
        var ty = (h * 0.33).toNumber();
        var by = (h * 0.71).toNumber();
        _field(dc, lx, ty, l1, v1);
        _field(dc, rx, ty, l2, v2);
        _field(dc, lx, by, l3, v3);
        _field(dc, rx, by, l4, v4);
    }

    // One quadrant: gray label above, white value below, centered on (x, y).
    function _field(dc, x, y, label, value) {
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y - 20, Graphics.FONT_XTINY, label,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y + 10, Graphics.FONT_NUMBER_MILD, value,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ================= formatting helpers =================

    function _hr(info) {
        if (info != null && info.currentHeartRate != null) {
            return info.currentHeartRate.toString();
        }
        return "--";
    }

    function _cal(info) {
        if (info != null && info.calories != null) {
            return info.calories.toString();
        }
        return "0";
    }

    // Seconds -> "m:ss" (or "h:mm:ss" past an hour).
    function _clock(sec) {
        var hrs = sec / 3600;
        var mins = (sec % 3600) / 60;
        var secs = sec % 60;
        if (hrs > 0) {
            return Lang.format("$1$:$2$:$3$", [hrs, mins.format("%02d"), secs.format("%02d")]);
        }
        return Lang.format("$1$:$2$", [mins, secs.format("%02d")]);
    }
}
