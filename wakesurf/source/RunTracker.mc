using Toybox.ActivityRecording as Rec;
using Toybox.FitContributor as Fit;
using Toybox.Activity;
using Toybox.Position;
using Toybox.System;
using Toybox.Lang;

// Ride states, declared at module scope so the view can reference them too.
enum {
    RS_WAITING = 0,   // idle / turnaround between runs
    RS_RIDING  = 1    // a run is in progress
}

// RunTracker owns the ActivityRecording session, records custom FIT fields,
// and runs the auto + manual "run" detection state machine.
//
// A "run" = one pull behind the boat. The view feeds this class one
// Activity.Info sample per second via onTick().
class RunTracker {

    // ---------- Auto-detection tunables ----------
    // Speeds are meters/second. 1 mph = 0.44704 m/s.
    // These are first-guess values; tune them after your first real session.
    const START_SPEED   = 4.0;  // ~14 km/h : cross this to start a run
    const STOP_SPEED    = 2.7;  // ~10 km/h : below this, a run may be ending
    const MIN_RUN_SEC   = 5;    // runs shorter than this are rejected as blips
    const END_GRACE_SEC = 4;    // low-speed seconds tolerated before ending a run
    const START_TICKS   = 2;    // consecutive fast samples before a run begins

    // ---------- Session + custom FIT fields ----------
    private var _session = null;
    private var _fRuns = null;
    private var _fMaxSpeed = null;
    private var _fLongestRun = null;
    private var _fRunNumber = null;

    // ---------- Live stats (read by the view) ----------
    public var state = RS_WAITING;
    public var runs = 0;                 // committed run count
    public var runNumber = 0;            // current/last run index (tentative during a run)
    public var currentRunSec = 0;        // elapsed seconds of the in-progress run
    public var longestRunSec = 0;
    public var maxSpeed = 0.0;           // session max speed (m/s)
    public var currentRunMaxSpeed = 0.0;
    public var gpsQuality = null;        // latest Position.Quality (drives the GPS dot)

    // ---------- Internal counters ----------
    private var _fastTicks = 0;          // consecutive samples >= START_SPEED while WAITING
    private var _graceLeft = 0;          // low-speed grace countdown while RIDING

    function initialize() {
    }

    function isRecording() {
        return (_session != null) && _session.isRecording();
    }

    function hasSession() {
        return _session != null;
    }

    // Turn GPS on as soon as the app opens so the pre-start GPS dot can climb
    // to a good fix while the user waits (matching native activity behavior).
    // Idempotent — safe to call repeatedly.
    function enableGps() {
        if (Toybox has :Position) {
            Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
        }
    }

    function disableGps() {
        if (Toybox has :Position) {
            Position.enableLocationEvents(Position.LOCATION_DISABLE, method(:onPosition));
        }
        gpsQuality = null;
    }

    // Position callback — keeps the current GPS quality fresh for the dot.
    function onPosition(loc as Position.Info) as Void {
        if (loc != null) {
            gpsQuality = loc.accuracy;
        }
    }

    // Create the recording session and register the custom FIT fields.
    function start() {
        if (!(Toybox has :ActivityRecording)) {
            return;
        }
        _resetStats();     // fresh session starts from zero
        enableGps();       // ensure GPS is running (usually already on from the splash)

        // No dedicated "wakesurf" FIT sport exists, so we record the closest
        // match: Surfing. It reads as "Surfing" in Garmin Connect and maps to
        // Strava's "Surf" type. The custom :name is what shows on the watch.
        // (Swap to Activity.SPORT_WAKEBOARDING if you prefer the tow-sport label.)
        _session = Rec.createSession({
            :name => "Wakesurf",
            :sport => Activity.SPORT_SURFING,
            :subSport => Activity.SUB_SPORT_GENERIC
        });

        // Session fields: written once, at save time (whole-session summaries).
        _fRuns = _session.createField(
            "runs", 0, Fit.DATA_TYPE_UINT16,
            { :mesgType => Fit.MESG_TYPE_SESSION, :units => "runs" });
        _fMaxSpeed = _session.createField(
            "maxSpeed", 1, Fit.DATA_TYPE_FLOAT,
            { :mesgType => Fit.MESG_TYPE_SESSION, :units => "m/s" });
        _fLongestRun = _session.createField(
            "longestRun", 2, Fit.DATA_TYPE_UINT16,
            { :mesgType => Fit.MESG_TYPE_SESSION, :units => "s" });
        // Record field: written each second so the run number graphs over time.
        _fRunNumber = _session.createField(
            "runNumber", 3, Fit.DATA_TYPE_UINT16,
            { :mesgType => Fit.MESG_TYPE_RECORD });

        _session.start();
    }

    // START/STOP pause + resume (native running behavior). Pausing keeps the
    // session; resuming continues it. The FIT records the paused segment.
    function pause() {
        if (_session != null && _session.isRecording()) {
            _session.stop();
        }
    }

    function resume() {
        if (_session != null && !_session.isRecording()) {
            _session.start();
        }
    }

    // Called once per second by the view while recording (not while paused).
    function onTick(info) {
        if (!isRecording()) {
            return;
        }

        var speed = 0.0;
        if (info != null && info.currentSpeed != null) {
            speed = info.currentSpeed;
        }

        if (speed > maxSpeed) {
            maxSpeed = speed;
        }

        if (state == RS_WAITING) {
            // Wait for a few consecutive fast samples before starting a run,
            // so a single GPS spike doesn't create a phantom run.
            if (speed >= START_SPEED) {
                _fastTicks += 1;
                if (_fastTicks >= START_TICKS) {
                    _beginRun();
                }
            } else {
                _fastTicks = 0;
            }
        } else { // RS_RIDING
            currentRunSec += 1;
            if (speed > currentRunMaxSpeed) {
                currentRunMaxSpeed = speed;
            }

            if (speed < STOP_SPEED) {
                // Slowing down — but tolerate brief dips (wake, chop, a cut).
                _graceLeft -= 1;
                if (_graceLeft <= 0) {
                    _endRun();
                }
            } else {
                _graceLeft = END_GRACE_SEC; // recovered speed, reset the grace window
            }
        }

        // Log which run we're on (0 while waiting) once per second.
        if (_fRunNumber != null) {
            _fRunNumber.setData(state == RS_RIDING ? runNumber : 0);
        }
    }

    // Manual override (BACK = LAP): start or end a run immediately, letting the
    // user correct a missed or false auto-detection without touching thresholds.
    function toggleRunManual() {
        if (!isRecording()) {
            return;
        }
        if (state == RS_WAITING) {
            _beginRun();
        } else {
            _endRun();
        }
    }

    private function _beginRun() {
        state = RS_RIDING;
        runNumber += 1;              // tentative until it survives MIN_RUN_SEC
        currentRunSec = 0;
        currentRunMaxSpeed = 0.0;
        _graceLeft = END_GRACE_SEC;
        _fastTicks = 0;
    }

    private function _endRun() {
        if (currentRunSec >= MIN_RUN_SEC) {
            runs += 1;
            if (currentRunSec > longestRunSec) {
                longestRunSec = currentRunSec;
            }
        } else {
            // Too short to count — undo the tentative run number.
            runNumber -= 1;
            if (runNumber < 0) {
                runNumber = 0;
            }
        }
        state = RS_WAITING;
        currentRunSec = 0;
        _graceLeft = 0;
        _fastTicks = 0;
    }

    // Stop recording, write the summary fields, and save the FIT file.
    function saveAndEnd() {
        if (_session == null) {
            return;
        }
        if (state == RS_RIDING) {
            _endRun(); // close out an in-progress run before summarizing
        }
        if (_fRuns != null) { _fRuns.setData(runs); }
        if (_fMaxSpeed != null) { _fMaxSpeed.setData(maxSpeed); }
        if (_fLongestRun != null) { _fLongestRun.setData(longestRunSec); }

        if (_session.isRecording()) {
            _session.stop();
        }
        _session.save();
        _session = null;
    }

    // Stop recording and throw the session away (nothing saved).
    function discard() {
        if (_session == null) {
            return;
        }
        if (_session.isRecording()) {
            _session.stop();
        }
        _session.discard();
        _session = null;
    }

    private function _resetStats() {
        state = RS_WAITING;
        runs = 0;
        runNumber = 0;
        currentRunSec = 0;
        longestRunSec = 0;
        maxSpeed = 0.0;
        currentRunMaxSpeed = 0.0;
        _fastTicks = 0;
        _graceLeft = 0;
    }
}
