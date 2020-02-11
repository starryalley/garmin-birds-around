using Toybox.Application;
using Toybox.System as Sys;

(:glance)
class garminbirdingApp extends Application.AppBase {
    hidden var view;

    function initialize() {
        AppBase.initialize();
        view = new garminbirdingView();
    }

    // onStart() is called on application start up
    function onStart(state) {
    }

    // onStop() is called when your application is exiting
    function onStop(state) {
    }

    // Return the initial view of your application here
    function getInitialView() {
        var deviceSettings = Sys.getDeviceSettings();
        if (deviceSettings has :isGlanceModeEnabled && deviceSettings.isGlanceModeEnabled) {
            Sys.println("Has glance, go directly into main view");
            return [view, new garminbirdingInputDelegate(view)];
        }
        return [new garminbirdingSummaryView(view), new garminbirdingSummaryInputDelegate(view)];

    }

    function getGlanceView() {
        return [new garminbirdingGlanceView(view)];
    }
}