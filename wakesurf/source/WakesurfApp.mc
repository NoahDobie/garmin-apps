using Toybox.Application;
using Toybox.WatchUi;

// Application entry point. Connect IQ instantiates this class, then asks it
// for the initial view + input delegate pair via getInitialView().
class WakesurfApp extends Application.AppBase {

    private var _view = null;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
    }

    // Release GPS when the app closes (the view keeps it on the whole time it
    // is open, including on the splash and while paused).
    function onStop(state) {
        if (_view != null) {
            _view.tracker.disableGps();
        }
    }

    // Return [ view, delegate ]. The delegate reads/writes the same view's
    // tracker, so both share one WakesurfView instance.
    function getInitialView() {
        _view = new WakesurfView();
        var delegate = new WakesurfDelegate(_view);
        return [ _view, delegate ];
    }
}
