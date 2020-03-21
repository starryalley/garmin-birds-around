using Toybox.WatchUi as Ui;
using Toybox.System as Sys;

(:glance)
class garminbirdingInputDelegate extends Ui.BehaviorDelegate {
    hidden var view;
    hidden var isVA4 = false;

    function initialize(v) {
        Ui.BehaviorDelegate.initialize();
        view = v;
        var dev = Sys.getDeviceSettings();
        if (dev.partNumber.equals("006-B3224-00") || dev.partNumber.equals("006-B3225-00")) {
            isVA4 = true;
            Sys.println("using VA4");
        }
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
        if (isVA4) {
            view.select();
        } else {
            view.requestNewLocation();
        }
        return true;
    }

    function onBack() {
        Sys.println("onBack()");
        return view.setSelectMode(false);
    }

    function onSelect() {
        Sys.println("onSelect()");
        if (isVA4) {
            view.nextPage();
        } else {
            view.select();
        }
        return true;
    }

    /*
    function onSwipe(evt) {
        var dir=evt.getDirection();
        Sys.println("swipe: "+dir);
        if(dir == Ui.SWIPE_UP) {
            view.nextPage();
            return true;
        }
        if(dir == Ui.SWIPE_DOWN) {
            view.prevPage();
            return true;
        }
        return false;
    }
    */
}

