using Toybox.ActivityRecording as Rec;
using Toybox.FitContributor as Fit;
using Toybox.ActivityMonitor;
using Toybox.Activity;
using Toybox.Application.Storage;
using Toybox.Lang;
using Toybox.Math;

// PadTracker owns the ActivityRecording session and estimates distance and
// steps from the user-entered treadmill speed and step cadence, since the
// watch can't see steps while your hands are on a keyboard.
//
// Speed is stored in tenths of a mph and cadence in steps/min (both ints) so
// the pickers step cleanly; both persist across launches via Storage.
class PadTracker {

    const MPH_TO_MPS = 0.44704;
    const M_PER_MILE = 1609.344;

    const DEFAULT_SPEED_TENTHS = 18;   // 1.8 mph
    const DEFAULT_CADENCE = 80;        // steps per minute

    // FIT native field numbers (see the FIT profile). A developer field given
    // :nativeNum is treated by Garmin Connect as that native field.
    const NATIVE_RECORD_DISTANCE = 5;
    const NATIVE_RECORD_SPEED = 6;
    const NATIVE_SESSION_TOTAL_DISTANCE = 9;

    // ---------- Settings (persisted) ----------
    public var speedTenths;
    public var cadence;

    // ---------- Live stats (read by the view) ----------
    public var distanceM = 0.0;
    public var steps = 0.0;
    public var watchSteps = 0;           // what the watch itself counted this session

    // ---------- Session + custom FIT fields ----------
    private var _session = null;
    private var _fDist = null;
    private var _fSpeed = null;
    private var _fTotalDist = null;
    private var _fSteps = null;
    private var _fCadence = null;
    private var _fWatchSteps = null;

    private var _lastTimerMs = 0;        // info.timerTime at the previous tick
    private var _startWatchSteps = null; // ActivityMonitor steps at session start

    function initialize() {
        speedTenths = _load("speedTenths", DEFAULT_SPEED_TENTHS);
        cadence = _load("cadence", DEFAULT_CADENCE);
    }

    function isRecording() {
        return (_session != null) && _session.isRecording();
    }

    function hasSession() {
        return _session != null;
    }

    function speedMps() {
        return speedTenths / 10.0 * MPH_TO_MPS;
    }

    function setSpeedTenths(v) {
        speedTenths = v;
        Storage.setValue("speedTenths", v);
    }

    function setCadence(v) {
        cadence = v;
        Storage.setValue("cadence", v);
    }

    // Estimated distance in hundredths of a mile (the save picker's units).
    function distanceHundredths() {
        return Math.round(distanceM / M_PER_MILE * 100).toNumber();
    }

    // Create the recording session and register the FIT fields.
    function start() {
        if (!(Toybox has :ActivityRecording)) {
            return;
        }
        distanceM = 0.0;
        steps = 0.0;
        watchSteps = 0;
        _lastTimerMs = 0;
        _startWatchSteps = _watchStepsNow();

        _session = Rec.createSession({
            :name => "Walking Pad",
            :sport => Activity.SPORT_WALKING,
            :subSport => Activity.SUB_SPORT_INDOOR_WALKING
        });

        // Record fields: written each second so distance/speed graph over time.
        _fDist = _session.createField(
            "distance", 0, Fit.DATA_TYPE_FLOAT,
            { :mesgType => Fit.MESG_TYPE_RECORD, :units => "m",
              :nativeNum => NATIVE_RECORD_DISTANCE });
        _fSpeed = _session.createField(
            "speed", 1, Fit.DATA_TYPE_FLOAT,
            { :mesgType => Fit.MESG_TYPE_RECORD, :units => "m/s",
              :nativeNum => NATIVE_RECORD_SPEED });
        // Session fields: written once, at save time.
        _fTotalDist = _session.createField(
            "total_distance", 2, Fit.DATA_TYPE_FLOAT,
            { :mesgType => Fit.MESG_TYPE_SESSION, :units => "m",
              :nativeNum => NATIVE_SESSION_TOTAL_DISTANCE });
        _fSteps = _session.createField(
            "steps", 3, Fit.DATA_TYPE_UINT32,
            { :mesgType => Fit.MESG_TYPE_SESSION, :units => "steps" });
        _fCadence = _session.createField(
            "cadence", 4, Fit.DATA_TYPE_UINT16,
            { :mesgType => Fit.MESG_TYPE_SESSION, :units => "spm" });
        _fWatchSteps = _session.createField(
            "watch_steps", 5, Fit.DATA_TYPE_UINT32,
            { :mesgType => Fit.MESG_TYPE_SESSION, :units => "steps" });

        _session.start();
    }

    // Flush the partial second before pausing so a speed change made while
    // paused doesn't apply to time walked at the old speed.
    function pause() {
        if (isRecording()) {
            onTick(Activity.getActivityInfo());
            _session.stop();
        }
    }

    function resume() {
        if (_session != null && !_session.isRecording()) {
            _session.start();
        }
    }

    // Called by the view about once per second. Uses the change in timerTime
    // (which excludes paused time) rather than counting ticks, so missed or
    // late ticks don't skew the totals.
    function onTick(info) {
        if (!isRecording() || info == null || info.timerTime == null) {
            return;
        }
        var nowMs = info.timerTime;
        var dt = (nowMs - _lastTimerMs) / 1000.0;
        _lastTimerMs = nowMs;
        if (dt > 0) {
            distanceM += speedMps() * dt;
            steps += cadence * dt / 60.0;
        }

        var ws = _watchStepsNow();
        if (ws != null && _startWatchSteps != null && ws >= _startWatchSteps) {
            watchSteps = ws - _startWatchSteps;  // daily count resets at midnight
        }

        if (_fDist != null) { _fDist.setData(distanceM); }
        if (_fSpeed != null) { _fSpeed.setData(speedMps()); }
    }

    // Stop recording and save, using the treadmill's distance (hundredths of
    // a mile) as the session total. Steps stay cadence-based.
    function saveAndEnd(distHundredths) {
        if (_session == null) {
            return;
        }
        if (_session.isRecording()) {
            _session.stop();
        }
        if (_fTotalDist != null) { _fTotalDist.setData(distHundredths / 100.0 * M_PER_MILE); }
        if (_fSteps != null) { _fSteps.setData(steps.toNumber()); }
        if (_fCadence != null) { _fCadence.setData(cadence); }
        if (_fWatchSteps != null) { _fWatchSteps.setData(watchSteps); }
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

    private function _watchStepsNow() {
        var am = ActivityMonitor.getInfo();
        return (am != null) ? am.steps : null;
    }

    private function _load(key, def) {
        var v = Storage.getValue(key);
        return (v instanceof Lang.Number) ? v : def;
    }
}
