using Toybox.WatchUi as Ui;
using Toybox.System as Sys;

(:glance)
class garminbirdingInputDelegate extends Ui.BehaviorDelegate {
    hidden var view;

    function initialize(v) {
        Ui.BehaviorDelegate.initialize();
        view = v;
    }

    function onNextPage() {
        Sys.println("onNextPage()");
        view.nextPage();
        return true;
    }

    function onPreviousPage() {
        Sys.println("onPreviousPage()");
        view.prevPage();
        return true;
    }

    function onMenu() {
        Sys.println("onMenu()");
        view.requestNewLocation();
        return true;
    }

    function onBack() {
        Sys.println("onBack()");
        return view.setSelectMode(false);
    }

    function onSelect() {
        Sys.println("onSelect()");
        view.select();
        return true;
    }
}

