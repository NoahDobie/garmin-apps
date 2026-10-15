using Toybox.Application;
using Toybox.WatchUi;

// Application entry point. Connect IQ instantiates this class, then asks it
// for the initial view + input delegate pair via getInitialView().
class WalkingPadApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
    }

    function onStop(state) {
    }

    // Return [ view, delegate ]. The delegate reads/writes the same view's
    // tracker, so both share one WalkingPadView instance.
    function getInitialView() {
        var view = new WalkingPadView();
        return [ view, new WalkingPadDelegate(view) ];
    }
}
