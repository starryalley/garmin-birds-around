using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.Communications as Comm;
using Toybox.System as Sys;
using Toybox.Time;
using Toybox.Application.Storage;

class garminbirdingSummaryView extends Ui.View {
    hidden var mainview;

    function initialize(view) {
        View.initialize();
        mainview = view;
    }

    function onShow() {
        Sys.println("Summary onShow()");
        Ui.requestUpdate();
    }

    function onHide() {
    }

    function onUpdate(dc) {
        dc.setColor(Gfx.COLOR_TRANSPARENT, Gfx.COLOR_BLACK);
        dc.clear();
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        var speciesCount = Storage.getValue("speciesCount");
        var lastFetchedContentAt = Storage.getValue("pageContentLastUpdate");
        var expired = false;
        if (lastFetchedContentAt != null && Time.now().value() - lastFetchedContentAt > 86400*3) {
            expired = true;
        }

        if (speciesCount == null || lastFetchedContentAt == null) {
            dc.drawText(dc.getWidth()/2, dc.getHeight()/2, Gfx.FONT_SMALL, "Birds Around",
                Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
        } else {
            var m = new Time.Moment(lastFetchedContentAt);
            var date = Time.Gregorian.info(m, Time.FORMAT_SHORT);
            var dateStr = format("$1$-$2$-$3$ $4$:$5$",[
                date.year,
                date.month.format("%02d"),
                date.day,
                date.hour,
                date.min.format("%02d")]);
            var textHeight = dc.getFontHeight(Gfx.FONT_TINY);
            dc.drawText(dc.getWidth()/2, dc.getHeight()/2 - dc.getHeight()/4, Gfx.FONT_SMALL, "Birds Around", Gfx.TEXT_JUSTIFY_CENTER);

            if (expired) {
                dc.setColor(0xffd2bd, Gfx.COLOR_TRANSPARENT);
                dc.drawText(dc.getWidth()/2, dc.getHeight()/2 + textHeight, Gfx.FONT_TINY, "*" + speciesCount + " species", Gfx.TEXT_JUSTIFY_CENTER);
                dc.drawText(dc.getWidth()/2, dc.getHeight()/2 + textHeight*2, Gfx.FONT_TINY, "Data too old.\nPlease update!", Gfx.TEXT_JUSTIFY_CENTER);
            } else {
                dc.setColor(0xbdffc9, Gfx.COLOR_TRANSPARENT);
                dc.drawText(dc.getWidth()/2, dc.getHeight()/2 + textHeight, Gfx.FONT_TINY, speciesCount + " species", Gfx.TEXT_JUSTIFY_CENTER);
                dc.drawText(dc.getWidth()/2, dc.getHeight()/2 + textHeight*2, Gfx.FONT_TINY, dateStr, Gfx.TEXT_JUSTIFY_CENTER);
            }
        }
    }
}

class garminbirdingSummaryInputDelegate extends Ui.BehaviorDelegate {
    var mainview;

    function initialize(view) {
        Ui.BehaviorDelegate.initialize();
        mainview = view;
    }

    function onSelect() {
        Ui.pushView(mainview, new garminbirdingInputDelegate(mainview), Ui.SLIDE_LEFT);
        return true;
    }
}