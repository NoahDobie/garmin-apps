using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Activity;
using Toybox.Position;
using Toybox.System;
using Toybox.Timer;
using Toybox.Lang;

// The main on-screen view. Owns the RunTracker, ticks it once per second, and
// renders one of three 4-field data pages plus a ride-state status arc.
class WakesurfView extends WatchUi.View {

    public var tracker;
    public var page = 0;                 // 0 = Main, 1 = Totals, 2 = Runs
    private const NUM_PAGES = 3;

    private var _timer = null;

    // Unit conversions (metric).
    private const MPS_TO_KMH = 3.6;
    private const M_TO_KM = 0.001;

    function initialize() {
        View.initialize();
        tracker = new RunTracker();
    }

    function onLayout(dc) {
    }

    // On show: start GPS (so the pre-start dot can climb to a good fix) and the
    // 1 Hz tick. Also runs when returning from the session menu — both are
    // idempotent.
    function onShow() {
        tracker.enableGps();
        if (_timer == null) {
            _timer = new Timer.Timer();
            _timer.start(method(:onTick), 1000, true);
        }
    }

    // Stop ticking when hidden (e.g. while the session menu is open). GPS and
    // the recording session keep running; GPS is only released on app exit.
    function onHide() {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
    }

    // Per-second: advance the tracker with a fresh sensor sample, redraw.
    // Typed as Void to match the Timer callback signature.
    function onTick() as Void {
        var info = Activity.getActivityInfo();
        tracker.onTick(info);
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

        var info = Activity.getActivityInfo();

        // Splash only when there is no session at all. A paused session still
        // shows the data pages (with a PAUSED arc).
        if (!tracker.hasSession()) {
            _drawSplash(dc);
            return;
        }

        _drawStatusArc(dc);
        _drawDividers(dc);
        if (page == 0) {
            _drawMainPage(dc, info);
        } else if (page == 1) {
            _drawTotalsPage(dc, info);
        } else {
            _drawRunsPage(dc, info);
        }
        _drawGpsDot(dc);
    }

    // Pre-record home screen, with a live GPS signal indicator.
    function _drawSplash(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (h * 0.28).toNumber(), Graphics.FONT_MEDIUM, "WAKESURF",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (h * 0.46).toNumber(), Graphics.FONT_SMALL, "Press START",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (h * 0.55).toNumber(), Graphics.FONT_TINY, "to begin",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // GPS status: colored dot + word (updates live as the fix improves).
        var q = tracker.gpsQuality;
        var y = (h * 0.72).toNumber();
        dc.setColor(_gpsColor(q), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle((cx - 8), y, 7);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText((cx + 6), y, Graphics.FONT_TINY, _gpsLabel(q),
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Thin arc along the top edge: green riding, amber waiting, blue paused.
    function _drawStatusArc(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;

        var color;
        var label;
        if (!tracker.isRecording()) {
            color = Graphics.COLOR_BLUE;   label = "PAUSED";
        } else if (tracker.state == RS_RIDING) {
            color = Graphics.COLOR_GREEN;  label = "RIDING";
        } else {
            color = Graphics.COLOR_ORANGE; label = "WAITING";
        }

        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(8);
        dc.drawArc(cx, cy, (w / 2) - 6, Graphics.ARC_CLOCKWISE, 130, 50);
        dc.setPenWidth(1);
        dc.drawText(cx, (h * 0.11).toNumber(), Graphics.FONT_XTINY, label,
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

    // Page 0 — the running-style 4-field page: time, speed, HR, runs.
    function _drawMainPage(dc, info) {
        _draw4(dc,
            "TIME",  _clock((info != null && info.timerTime != null) ? info.timerTime / 1000 : 0),
            "KM/H",  _kmh(info != null ? info.currentSpeed : null),
            "HR",    _hr(info),
            "RUNS",  tracker.runs.toString());
    }

    // Page 1 — session totals: avg speed, max speed, distance, calories.
    function _drawTotalsPage(dc, info) {
        _draw4(dc,
            "AVG KMH",  _kmh(info != null ? info.averageSpeed : null),
            "MAX KMH",  _kmh(tracker.maxSpeed),
            "DIST KM",  _km(info != null ? info.elapsedDistance : null),
            "CAL",      _cal(info));
    }

    // Page 2 — run detail: count, current run time, longest run, run top speed.
    function _drawRunsPage(dc, info) {
        _draw4(dc,
            "RUNS",     tracker.runs.toString(),
            "THIS RUN", _clock(tracker.currentRunSec),
            "LONGEST",  _clock(tracker.longestRunSec),
            "RUN KMH",  _kmh(tracker.currentRunMaxSpeed));
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

    // Small GPS-quality dot, low-center on every data page.
    function _drawGpsDot(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(_gpsColor(tracker.gpsQuality), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(w / 2, (h * 0.90).toNumber(), 5);
    }

    // ================= formatting helpers =================

    function _kmh(mps) {
        if (mps == null) {
            return "0.0";
        }
        return (mps * MPS_TO_KMH).format("%.1f");
    }

    function _km(meters) {
        if (meters == null) {
            return "0.00";
        }
        return (meters * M_TO_KM).format("%.2f");
    }

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
        if (sec == null) {
            sec = 0;
        }
        var hrs = sec / 3600;
        var mins = (sec % 3600) / 60;
        var secs = sec % 60;
        if (hrs > 0) {
            return Lang.format("$1$:$2$:$3$", [hrs, mins.format("%02d"), secs.format("%02d")]);
        }
        return Lang.format("$1$:$2$", [mins, secs.format("%02d")]);
    }

    // Position.Quality -> color. 0 NOT_AVAILABLE, 1 LAST_KNOWN, 2 POOR,
    // 3 USABLE, 4 GOOD.
    function _gpsColor(q) {
        if (q == null) {
            return Graphics.COLOR_DK_GRAY;
        }
        if (q >= 3) {                      // USABLE or GOOD -> accurate
            return Graphics.COLOR_GREEN;
        }
        if (q >= 1) {                      // LAST_KNOWN or POOR -> acquiring/weak
            return Graphics.COLOR_ORANGE;
        }
        return Graphics.COLOR_RED;         // NOT_AVAILABLE
    }

    function _gpsLabel(q) {
        if (q == null || q == 0) {
            return "No GPS";
        }
        if (q == 1) {
            return "Acquiring";
        }
        if (q == 2) {
            return "Weak";
        }
        if (q == 3) {
            return "Good";
        }
        return "Ready";                    // GOOD
    }
}
