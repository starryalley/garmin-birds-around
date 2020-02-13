using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.Communications as Comm;
using Toybox.System as Sys;
using Toybox.Time;
using Toybox.Application.Storage;

(:glance)
class garminbirdingGlanceView extends Ui.GlanceView {
    hidden var mainview;

    function initialize(view) {
        GlanceView.initialize();
        mainview = view;
    }

    function onShow() {
        Sys.println("Glance view onShow()");
    }

    function onHide() {
    }

    function onUpdate(dc) {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var textHeightTiny = dc.getFontHeight(Gfx.FONT_TINY);
        var textHeightXTiny = dc.getFontHeight(Gfx.FONT_XTINY);

        Sys.println("Glance onUpdate(): width:" + dc.getWidth() + " height:" + dc.getHeight());
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        var speciesCount = Storage.getValue("speciesCount");
        var lastFetchedContentAt = Storage.getValue("pageContentLastUpdate");
        var expired = false;
        if (lastFetchedContentAt != null && Time.now().value() - lastFetchedContentAt > 86400*3) {
            expired = true;
        }

        if (speciesCount == null || lastFetchedContentAt == null) {
            dc.drawText(0, 0, Gfx.FONT_TINY, "No Birds Around", Gfx.TEXT_JUSTIFY_LEFT);
            dc.setColor(0xbdffc9, Gfx.COLOR_TRANSPARENT);
            dc.drawText(0, textHeightTiny, Gfx.FONT_XTINY, "Start widget to update", Gfx.TEXT_JUSTIFY_LEFT);
        } else {
            var m = new Time.Moment(lastFetchedContentAt);
            var date = Time.Gregorian.info(m, Time.FORMAT_SHORT);
            var dateStr = format("$1$-$2$-$3$",[
                date.year,
                date.month.format("%02d"),
                date.day]);

            if (expired) {
                dc.drawText(0, 0, Gfx.FONT_TINY, "*" + speciesCount + " ", Gfx.TEXT_JUSTIFY_LEFT);
                var offset = dc.getTextWidthInPixels("*" + speciesCount + " ", Gfx.FONT_TINY);
                dc.drawText(offset, textHeightTiny-textHeightXTiny, Gfx.FONT_XTINY, "Bird Species Around", Gfx.TEXT_JUSTIFY_LEFT);
                dc.setColor(0xffd2bd, Gfx.COLOR_TRANSPARENT);
                dc.drawText(0, textHeightTiny, Gfx.FONT_XTINY, "Data too old. Please update!", Gfx.TEXT_JUSTIFY_LEFT);
            } else {
                dc.drawText(0, 0, Gfx.FONT_TINY, speciesCount + " ", Gfx.TEXT_JUSTIFY_LEFT);
                var offset = dc.getTextWidthInPixels(speciesCount + " ", Gfx.FONT_TINY);
                dc.drawText(offset, textHeightTiny-textHeightXTiny, Gfx.FONT_XTINY, "Bird Species Around", Gfx.TEXT_JUSTIFY_LEFT);
                dc.setColor(0xbdffc9, Gfx.COLOR_TRANSPARENT);
                var infoText = Storage.getValue("searchRadius") + "km " + Storage.getValue("daysBack") + "d " + dateStr;
                dc.drawText(0, textHeightTiny, Gfx.FONT_XTINY, infoText, Gfx.TEXT_JUSTIFY_LEFT);
            }
        }
    }
}
