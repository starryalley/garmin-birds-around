using Toybox.WatchUi;
using Toybox.Communications as Comm;
using Toybox.Time;
using Toybox.Timer;
using Toybox.Math;
using Toybox.Application.Storage; // CIQ 2.4

(:glance)
class garminbirdingView extends WatchUi.View {
    hidden const ebirdToken = "API_TOKEN HERE"; // put your eBird API token here

    hidden var statusText = "No Info";
    hidden var font = Graphics.FONT_TINY;

    hidden var locationTimer;
    hidden var lon = null;
    hidden var lat = null;
    hidden var locationLastUpdatedAt = 0;
    hidden var textHeight = 20;
    hidden var screenHeight;
    hidden var screenWidth;
    hidden var screenShape;

    hidden var currentBirds = []; // temp data structure used when requesting ebird only
    hidden var speciesCount = 0; // species count
    hidden var page = 0; // current page (0-based)
    hidden var pageContents = []; // each page's content. This is the main data structure

    hidden var birdReady = false; //pagination has completed, ready for entering select/detail mode
    hidden var detailMode = false; // in bird detail screen
    hidden var selectMode = false; // in bid list screen but now in selection mode (showing selected bird)
    hidden var selected = 0; // current selected index

    hidden var searchRadius;
    hidden var daysBack;

    /*
    // TODO: switch to this state machine
    enum {
        MODE_FETCHING,  // when fetching data from internet
        MODE_ERROR,     // error state
        MODE_LIST,      // the bird list screen
        MODE_SELECT,    // the bird list screen with user selection
        MODE_DETAIL     // the bird detail screen
    }
    */

    function initialize() {
        View.initialize();
        locationTimer = new Timer.Timer();
    }

    // convert property value (number) to actual locale string used for eBird.
    // the property/settings in CIQ doesn't allow string type list which is absurd.
    function getLocale() {
        var locale = Application.getApp().getProperty("ebirdLocale");
        var l = "en";
        switch (locale) {
            case 0: l="en";break;
            case 1: l="en_AU";break;
            case 2: l="en_IN";break;
            case 3: l="en_IOC";break;
            case 4: l="en_HAW";break;
            case 5: l="en_KE";break;
            case 6: l="en_MY";break;
            case 7: l="en_NZ";break;
            case 8: l="en_PH";break;
            case 9: l="en_ZA";break;
            case 10: l="en_AE";break;
            case 11: l="en_UK";break;
            case 12: l="en_US";break;
            case 13: l="bg";break;
            case 14: l="zh";break;
            case 15: l="zh_SIM";break;
            case 16: l="hr";break;
            case 17: l="cz";break;
            case 18: l="da";break;
            case 19: l="nl";break;
            case 20: l="de";break;
            case 21: l="fo";break;
            case 22: l="fi";break;
            case 23: l="fr";break;
            case 24: l="fr_AOU";break;
            case 25: l="fr_CA";break;
            case 26: l="fr_GP";break;
            case 27: l="fr_HT";break;
            case 28: l="ht_HT";break;
            case 29: l="iw";break;
            case 30: l="hu";break;
            case 31: l="id";break;
            case 32: l="is";break;
            case 33: l="it";break;
            case 34: l="ja";break;
            case 35: l="ko";break;
            case 36: l="lv";break;
            case 37: l="lt";break;
            case 38: l="ml";break;
            case 39: l="mn";break;
            case 40: l="no";break;
            case 41: l="pl";break;
            case 42: l="pt_BR";break;
            case 43: l="pt_PT";break;
            case 44: l="ru";break;
            case 45: l="sr";break;
            case 46: l="sl";break;
            case 47: l="es";break;
            case 48: l="es_AR";break;
            case 49: l="es_CL";break;
            case 50: l="es_CR";break;
            case 51: l="es_CU";break;
            case 52: l="es_DO";break;
            case 53: l="es_EC";break;
            case 54: l="es_ES";break;
            case 55: l="es_MX";break;
            case 56: l="es_PA";break;
            case 57: l="es_PR";break;
            case 58: l="es_UY";break;
            case 59: l="es_VE";break;
            case 60: l="sv";break;
            case 61: l="th";break;
            case 62: l="tr";break;
            case 63: l="uk";break;
        }
        return l;
    }

    // get the visible screenWidth in pixels at position Y, depending on screen shape
    function getScreenWidthAtY(y) {
        if (screenShape == System.SCREEN_SHAPE_RECTANGLE) {
            return screenWidth;
        }
        var r = screenWidth / 2;
        return 2 * Math.sqrt(Math.pow(r, 2) - Math.pow(r-y, 2));
    }

    // retrieve saved location if it is still valid (currently set to less than 3 days)
    function getSavedLocation() {
        /*
        var info = Activity.getActivityInfo();
        if (info != null) {
            var locAccuracy = info.currentLocationAccuracy;
            if (locAccuracy == Position.QUALITY_LAST_KNOWN || locAccuracy == Position.QUALITY_GOOD) {
                var curLoc = info.currentLocation;
                if (curLoc != null) {
                    lat = curLoc.toDegrees()[0].toFloat();
                    lon = curLoc.toDegrees()[1].toFloat();
                    if (lon < -180 || lon > 180 || lat < -90 || lat > 90) {
                        System.println("Invalid last location");
                    } else {
                        locationLastUpdatedAt = Time.now().value();
                        System.println("Using last activity location:" + lat + "," + lon);
                        Storage.setValue("latitude", lat);
                        Storage.setValue("longitude", lon);
                        return true;
                    }
                }
            }
        }
        */
        var lastUpdated = Storage.getValue("locationUpdateTime");
        if (lastUpdated == null || (lastUpdated != null && Time.now().value() - lastUpdated > 86400*3)) {
            System.println("Last saved location is too old (more than 3 days ago)");
            // invalidate the location
            return false;
        }
        lat = Storage.getValue("latitude");
        lon = Storage.getValue("longitude");
        if (lat != null && lon != null) {
            System.println("Using last saved location:" + lat + "," + lon);
            return true;
        }
        return false;
    }

    // requesting ebird for recent observations at current lat/lon
    function requestRecentObs(dist, back, notable) {
        if (lon == null || lat == null) {
            System.println("No location, not requesting ebird");
            return;
        }
        if (lon < -180 || lon > 180 || lat < -90 || lat > 90) {
            System.println("Invalid location");
            return;
        }
        if (dist > 50 || dist < 0) {
            System.println("Distance should be 0-50");
            return;
        }
        if (back < 1 || back > 30) {
            System.println("back should be 1-30");
            return;
        }
        var locale = getLocale();
        System.println("Requesting eBird (" + locale + ") with radius=" + dist + "km,daysBack=" + back + ",notable_only=" + notable);
        birdReady = false;
        // invalidate saved content
        Storage.setValue("pageContentLastUpdate", 0);
        Storage.setValue("speciesCount", 0);
        // save current search radius and daysBack
        Storage.setValue("searchRadius", dist);
        Storage.setValue("daysBack", back);

        var params = {
            "lat" => lat,
            "lng" => lon,
            "sort" => "species",
            "dist" => dist,
            "back" => back,
            "sppLocale" => locale,//https://support.ebird.org/support/solutions/articles/48000804865-bird-names-in-ebird
        };
        var url = "https://api.ebird.org/v2/data/obs/geo/recent";
        if (notable) {
            url = "https://api.ebird.org/v2/data/obs/geo/recent/notable";
        }
        Comm.makeWebRequest(
            url,
            params,
            {
                :method => Comm.HTTP_REQUEST_METHOD_GET,
                :headers => { "X-eBirdApiToken" => ebirdToken },
                :responseType => Comm.HTTP_RESPONSE_CONTENT_TYPE_JSON,
            },
            method(:onReceiveObs)
        );
    }

    // requesting bird taxonomy data so we know how to group birds in the bird list
    function requestTaxonomy(speciesCodes) {
        var speciesList = "";
        for (var i = 0; i < speciesCodes.size(); i++) {
            speciesList += speciesCodes[i] + ",";
        }
        System.println("Requesting family name of:" + speciesList);
        Comm.makeWebRequest(
            "https://api.ebird.org/v2/ref/taxonomy/ebird",
            {
                "fmt" => "json",
                "species" => speciesList,
                "locale" => getLocale(),
            },
            {
                :method => Comm.HTTP_REQUEST_METHOD_GET,
                :headers => { "X-eBirdApiToken" => ebirdToken },
                :responseType => Comm.HTTP_RESPONSE_CONTENT_TYPE_JSON,
            },
            method(:onReceiveTaxonomy)
        );
    }

    // just a function to deduplicate based on bird scentific name
    function removeDuplicates(birdList) {
        var results = [];
        var species = {};
        for (var i = 0; i < birdList.size(); i++) {
            if (!species.hasKey(birdList[i]["sciName"])) {
                results.add(birdList[i]);
                species[birdList[i]["sciName"]] = 1;
            } else {
                //species[birdList[i]["sciName"]]++;
            }
        }
        return results;
    }

    // group currentBirds based on its family, returning a dictionary whose key is family name
    // and value is array of birds
    function createTaxonomy() {
        var birdsTaxonomy = {}; // familyComName => [birds]
        for (var i = 0; i < currentBirds.size(); i++) {
            var b = currentBirds[i];
            var f = b["family"];
            if (birdsTaxonomy.hasKey(f)) {
                birdsTaxonomy[f].add(b);
            } else {
                birdsTaxonomy[f] = [b];
            }
        }
        return birdsTaxonomy;
    }

    // callback for ebird observation request
    function onReceiveObs(responseCode, json) {
        System.println("obs response:" + responseCode);
        if (responseCode == Comm.NETWORK_RESPONSE_TOO_LARGE ||
                Comm has :NETWORK_RESPONSE_OUT_OF_MEMORY && responseCode == Comm.NETWORK_RESPONSE_OUT_OF_MEMORY) {
            if (searchRadius >= 10) {
                searchRadius -= 5;
            } else if (searchRadius >= 5) {
                searchRadius -= 1;
            } else if (searchRadius >= 1) {
                System.println("Results too big!");
                statusText = "Too many results\nReduce radius/days";
                WatchUi.requestUpdate();
                return;
            }
            System.println("Results too big, reducing radius from " + Application.getApp().getProperty("searchRadius") + " to " + searchRadius);
            requestRecentObs(searchRadius, Application.getApp().getProperty("daysBack"), false);
            statusText = "Requesting eBird\nRadius=" + searchRadius + "km";
        } else if (responseCode == 200) {
            //System.println("Receiving " + json.size() + " results");
            if (json.size() == 0) {
                if (daysBack <= 10) {
                    daysBack = 14;
                } else if (daysBack <= 21) {
                    daysBack = 30;
                } else {
                    System.println("No Result!");
                    statusText = "No Observation\nIncrease Radius";
                    WatchUi.requestUpdate();
                    return;
                }
                System.println("No results, increasing daysBack from " + Application.getApp().getProperty("daysBack") + " to " + daysBack);
                requestRecentObs(searchRadius, daysBack, false);
                statusText = "Requesting eBird\nDays=" + daysBack;
                WatchUi.requestUpdate();
                return;
            }
            var speciesCodes = [];
            currentBirds =removeDuplicates(json);
            for (var i = 0; i < currentBirds.size(); i++) {
                var speciesCode = currentBirds[i]["speciesCode"];
                speciesCodes.add(speciesCode);
            }
            requestTaxonomy(speciesCodes);
            statusText = "Requesting Taxonomy...";
        } else {
            statusText = "Error " + responseCode;
        }
        WatchUi.requestUpdate();
    }

    // callback for ebird taxonomy request
    function onReceiveTaxonomy(responseCode, json) {
        System.println("taxonomy response:" + responseCode);
        if (responseCode == Comm.NETWORK_RESPONSE_TOO_LARGE ||
                Comm has :NETWORK_RESPONSE_OUT_OF_MEMORY && responseCode == Comm.NETWORK_RESPONSE_OUT_OF_MEMORY) {
            statusText = "Too many results\nReduce radius/days";
        } else if (responseCode == 200) {
            if (json.size() != currentBirds.size()) {
                System.println("Unexpected count of taxonomy:" + json.size() + " != " + currentBirds.size());
                statusText = "Taxonomy Error\nOops...";
            } else {
                for (var i = 0; i < json.size(); i++) {
                    if (json[i].hasKey("familyComName")) {
                        currentBirds[i]["family"] = json[i]["familyComName"];
                    } else {
                        currentBirds[i]["family"] = "Unknown";
                    }
                    //System.println(currentBirds[i]["comName"] + "(" + currentBirds[i]["family"] + ")");
                }
                var taxonomy = createTaxonomy();
                speciesCount = currentBirds.size();
                currentBirds = []; // clear memory
                paginate(taxonomy);
            }
        } else {
            statusText = "Error " + responseCode;
        }
        WatchUi.requestUpdate();
    }

    function onLayout(dc) {
        screenHeight = dc.getHeight();
        screenWidth = dc.getWidth();
        screenShape = System.getDeviceSettings().screenShape;
        searchRadius = Application.getApp().getProperty("searchRadius");
        daysBack = Application.getApp().getProperty("daysBack");
        System.println("onLayout(): text height:" + textHeight);
    }

    function onUpdate(dc) {
        font = Application.getApp().getProperty("fontSize");
        textHeight = dc.getFontHeight(font);

        View.onUpdate(dc);
        dc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_BLACK);
        dc.clear();
        if (detailMode) {
            printBirdDetail(dc);
        } else {
            printBird(dc, page);
            // print selection
            if (selectMode) {
                printSelection(dc);
            }
            // print page
            printPageInfo(dc);
        }
    }

    function splitString(s) {
        var f = s.find(",");
        if (f) {
            return s.substring(0, f + 1) + "\n" + s.substring(f+1, s.length());
        }
        f = s.find("(");
        if (f) {
            return s.substring(0, f) + "\n" + s.substring(f, s.length());
        }
        f = s.find("-");
        if (f) {
            return s.substring(0, f) + "\n" + s.substring(f+1, s.length());
        }
        f = s.find(" ");
        if (f) {
            return s.substring(0, f) + "\n" + s.substring(f+1, s.length());
        }
        var h = (s.length()/2).toLong();
        return s.substring(0, h) + "\n" + s.substring(h, s.length());
    }

    function printBirdDetail(dc) {
        var bird = pageContents[page][selected];
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        // name
        var startOffset = 10;
        var squeezedTextHeight = textHeight-textHeight/3;
        if (dc.getTextWidthInPixels(bird["name"], font) > getScreenWidthAtY(startOffset)) {
            var f = bird["name"].find(" ");
            if (f) {
                var first = bird["name"].substring(0, f);
                var second = bird["name"].substring(f+1, bird["name"].length());
                dc.drawText(screenWidth/2, startOffset, font, first, Graphics.TEXT_JUSTIFY_CENTER);
                dc.drawText(screenWidth/2, startOffset+squeezedTextHeight, font, second, Graphics.TEXT_JUSTIFY_CENTER);
            } else {
                // can't be properly split
                dc.drawText(screenWidth/2, startOffset+squeezedTextHeight, font, bird["name"], Graphics.TEXT_JUSTIFY_CENTER);
            }
        } else {
            dc.drawText(screenWidth/2, startOffset+squeezedTextHeight, font, bird["name"], Graphics.TEXT_JUSTIFY_CENTER);
        }
        var y = startOffset + textHeight + squeezedTextHeight;
        dc.drawLine(0, y, screenWidth, y);

        // titles
        dc.setColor(0xbdffc9, Graphics.COLOR_TRANSPARENT);
        dc.drawText(screenWidth/2, y + textHeight * 0, font, "Scientific Name", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(screenWidth/2, y + textHeight * 2, font, "Observed Date/Count", Graphics.TEXT_JUSTIFY_CENTER);
        var locTitle = "Location";
        if (bird.hasKey("d")) {
            locTitle += " (" + bird["d"].format("%.1f") + "km)";
        }
        dc.drawText(screenWidth/2, y + textHeight * 4, font, locTitle, Graphics.TEXT_JUSTIFY_CENTER);
        if (y + textHeight * 8 < screenHeight) {
            dc.drawText(screenWidth/2, y + textHeight * 6, font, "Count", Graphics.TEXT_JUSTIFY_CENTER);
        }
        // content
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        if (dc.getTextWidthInPixels(bird["sci"], font) > getScreenWidthAtY(y + textHeight * 1)) {
            dc.drawText(screenWidth/2, y + textHeight * 1, Graphics.FONT_XTINY, bird["sci"], Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.drawText(screenWidth/2, y + textHeight * 1, font, bird["sci"], Graphics.TEXT_JUSTIFY_CENTER);
        }
        var birdCount = bird["ct"];
        if (birdCount == null) {
            birdCount = "N/A";
        }
        dc.drawText(screenWidth/2, y + textHeight * 3, font, bird["dt"].substring(0, 11) + ", " + birdCount, Graphics.TEXT_JUSTIFY_CENTER);
        if (dc.getTextWidthInPixels(bird["loc"], font) > getScreenWidthAtY(y + textHeight * 5)) {
            dc.drawText(screenWidth/2, y + textHeight * 5, Graphics.FONT_XTINY, splitString(bird["loc"]), Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.drawText(screenWidth/2, y + textHeight * 5, font, bird["loc"], Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    function printBird(dc, page) {
        var posY = textHeight;
        if (page >= pageContents.size()) {
            System.println("Showing centered status text:" + statusText);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(screenWidth/2, screenHeight/2, Graphics.FONT_TINY, statusText, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        for (var i = 0; i < pageContents[page].size(); i++) {
            var info = pageContents[page][i];
            if (info.hasKey("fam") && info["fam"]) {
                dc.setColor(0xe1ffbd, Graphics.COLOR_TRANSPARENT);
                dc.drawText(screenWidth/2, posY, font, info["name"], Graphics.TEXT_JUSTIFY_CENTER);
                var textWidth = dc.getTextWidthInPixels(info["name"], font);
                var textOffset = (screenWidth-textWidth)/2;
                //dc.drawLine(textOffset, posY, screenWidth-textOffset, posY);
                var round = 10;
                dc.drawRoundedRectangle(textOffset-round/2, posY, textWidth + round, textHeight, round);
            } else {
                dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.drawText(screenWidth/2, posY, font, info["name"], Graphics.TEXT_JUSTIFY_CENTER);
                //pageContents[page][i]["width"] = dc.getTextWidthInPixels(info["name"], font);
            }
            posY += textHeight;
        }
    }

    function printPageInfo(dc) {
        if (birdReady) {
            var tinyHeight = dc.getFontHeight(Graphics.FONT_XTINY);
            // print total species count
            dc.setColor(0xa3ffe2, Graphics.COLOR_TRANSPARENT);
            dc.drawText(screenWidth/2, textHeight-tinyHeight, Graphics.FONT_XTINY, "Species:" + speciesCount, Graphics.TEXT_JUSTIFY_CENTER);
            // print current location
            //var location = lat.format("%.5f") + ", " + lon.format("%.5f");
            //dc.setColor(0xa3ffe2, Graphics.COLOR_TRANSPARENT);
            //dc.drawText(screenWidth/2, screenHeight - tinyHeight*2 + tinyHeight/3, Graphics.FONT_XTINY, location, Graphics.TEXT_JUSTIFY_CENTER);
            // print current/total page
            dc.setColor(0xa3ffe2, Graphics.COLOR_TRANSPARENT);
            dc.drawText(screenWidth/2, screenHeight - tinyHeight, Graphics.FONT_XTINY, (page + 1) + "/" + pageContents.size(), Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    function printSelection(dc) {
        if (selected >= pageContents[page].size()) {
            System.println("Wrong selection index:" + selected + " (total:" + pageContents[page].size() + ")");
            return;
        }
        dc.setColor(0xffd2bd, Graphics.COLOR_TRANSPARENT);
        var round = 10;
        System.println("selected:" + selected + ", total item on page " + page + ": " + pageContents[page].size());
        var textWidth = dc.getTextWidthInPixels(pageContents[page][selected]["name"], font);
        var x = (screenWidth - textWidth - round)/2;
        dc.drawRoundedRectangle(x, (selected + 1) * textHeight, textWidth + round, textHeight, round);
    }

    // generate an array of array
    // pageContents[0] => [{
    //     "name" => textToDisplay,
    //     "fam" => true,
    //   },
    //   {}...
    // ]
    function paginate(birdsTaxonomy) {
        pageContents = [];
        var currentPage = 0;
        var currentPageContent = [];

        var families = birdsTaxonomy.keys();
        var posY = textHeight;
        for (var i = 0; i < families.size(); i++) {
            var family = families[i];
            posY += textHeight;
            if (posY > screenHeight - textHeight) {
                System.println("Page " + currentPage + " paginated");
                pageContents.add(currentPageContent);
                currentPage += 1;
                currentPageContent = [];
                posY = textHeight;
                i -= 1;
                continue;
            }
            currentPageContent.add({"name" => family, "fam" => true});

            System.println("Family[" + family + "]:" + birdsTaxonomy[family].size() + " birds");
            for (var j = 0; j < birdsTaxonomy[family].size(); j++) {
                var bird = birdsTaxonomy[family][j];
                //System.println("=> [" + bird["comName"] + "]");
                posY += textHeight;
                if (posY > screenHeight - textHeight) {
                    System.println("Page " + currentPage + " paginated");
                    pageContents.add(currentPageContent);
                    currentPage += 1;
                    currentPageContent = [];
                    posY = textHeight;
                    j -= 1; // repeat the last one the new page
                    continue;
                }
                currentPageContent.add({
                    "name" => bird["comName"],
                    //"fam" => false, // reducing memory, not adding this key
                    "loc" => bird["locName"],
                    "dt" => bird["obsDt"],
                    "sci" => bird["sciName"],
                    "ct" => bird["howMany"],
                    "d" => getDistanceTo(bird["lat"], bird["lng"]), //distance to current location
                });
            }
        }
        if (currentPageContent.size() > 0) {
            System.println("Last Page " + currentPage + " paginated");
            pageContents.add(currentPageContent);
        }
        // save current content in App storage, Keys and values are limited to 8 KB each, and a total of 128 KB of storage is available.
        Storage.setValue("pageContents", pageContents);
        Storage.setValue("speciesCount", speciesCount);
        Storage.setValue("pageContentLastUpdate", Time.now().value());
        birdReady = true;
    }

    function _incrementPage() {
        if (page == pageContents.size() - 1) {
            page = 0;
        } else {
            page += 1;
        }
    }

    function _decrementPage() {
        if (page == 0) {
            page = pageContents.size() - 1;
        } else {
            page -= 1;
        }
    }

    function _incrementSelection() {
        if (selected == pageContents[page].size() - 1) {
            selected = 0;
            _incrementPage();
        } else {
            selected += 1;
        }
        if (pageContents[page][selected].hasKey("fam") && pageContents[page][selected]["fam"]) {
            _incrementSelection();
        }
    }

    function _decrementSelection() {
        if (selected == 0) {
            _decrementPage();
            selected = pageContents[page].size() - 1;
        } else {
            selected -= 1;
        }
        // skip family
        if (pageContents[page][selected].hasKey("fam") && pageContents[page][selected]["fam"]) {
            _decrementSelection();
        }
    }

    function prevPage() {
        if (!birdReady) {
            return;
        }
        if (!selectMode) {
            _decrementPage();
        } else {
           _decrementSelection();
        }
        WatchUi.requestUpdate();
    }

    function nextPage() {
        if (!birdReady) {
            return;
        }
        if (!selectMode) {
            _incrementPage();
        } else {
            _incrementSelection();
        }
        WatchUi.requestUpdate();
    }

    function onPosition(info) {
        var myLocation = info.position.toDegrees();
        lat = myLocation[0];
        lon = myLocation[1];
        if (lon < -180 || lon > 180 || lat < -90 || lat > 90) {
            System.println("Invalid GPS location received, let's re-do it in 5 sec");
            locationTimer.start(method(:onTimer), 5 * 1000, false);
            return;
        }
        Storage.setValue("latitude", lat);
        Storage.setValue("longitude", lon);
        Storage.setValue("locationUpdateTime", Time.now().value());
        System.println("Got GPS Location: Latitude: " + myLocation[0] + ", Longitude: " + myLocation[1] + ". Requesting eBird...");
        requestRecentObs(Application.getApp().getProperty("searchRadius"), Application.getApp().getProperty("daysBack"), false);
        statusText = "Requesting eBird...\nRadius=" + Application.getApp().getProperty("searchRadius") + "km Days=" + Application.getApp().getProperty("daysBack");
        WatchUi.requestUpdate();
    }

    function setSelectMode(enabled) {
        // if we are already in view mode and we click back, let's exit program
        if (!selectMode && !enabled) {
            return false;
        }
        // if we call this too early, let's ignore
        if (!birdReady) {
            System.println("Bird list not downloaded completely yet");
            return true;
        }
        if (!enabled && detailMode) {
            // let's disable detail mode
            detailMode = false;
        } else {
            selectMode = enabled;
            selected = 0; // reset selection
            if (selectMode) {
               // check selection
               if (pageContents[page][selected].hasKey("fam") && pageContents[page][selected]["fam"]) {
                   nextPage();
               }
            }
        }
        WatchUi.requestUpdate();
        return true;
    }

    function select() {
        if (selectMode) {
            detailMode = true;
            WatchUi.requestUpdate();
        } else {
            // not yet in selection mode, seting selection mode now
            setSelectMode(true);
        }
    }

    function clearFetchedData() {
        pageContents = [];
        page = 0;
        speciesCount = 0;
        // when we clear data, we should also clear current selection since it's now empty
        selected = 0;
        detailMode = false; // force out of bird detail screen
        selectMode = false; // force out of selection mode
        birdReady = false; // nothing to show
    }

    function requestNewLocation() {
        Position.enableLocationEvents(Position.LOCATION_ONE_SHOT, method(:onPosition));
        statusText = "Starting GPS...";
        clearFetchedData();
        WatchUi.requestUpdate();
    }

    function onTimer() {
        if (!birdReady) {
            if (!getSavedLocation()) {
                // no last stored location
                System.println("No location info, requesting GPS location");
                statusText = "Requesting GPS...";
                Position.enableLocationEvents(Position.LOCATION_ONE_SHOT, method(:onPosition));
                WatchUi.requestUpdate();
            } else {
                // now that we are using saved location, just fetch the last saved contents as well
                var lastFetchedContentAt = Storage.getValue("pageContentLastUpdate");
                if (lastFetchedContentAt != null && Time.now().value() - lastFetchedContentAt < 86400*3) {
                    System.println("Last fetched observation is less than 3 days old, reusing...");
                    pageContents = Storage.getValue("pageContents");
                    speciesCount = Storage.getValue("speciesCount");
                    page = 0;
                    birdReady = true;
                    WatchUi.requestUpdate();
                } else {
                    System.println("Requesting ebird...");
                    clearFetchedData();
                    requestRecentObs(Application.getApp().getProperty("searchRadius"), Application.getApp().getProperty("daysBack"), false);
                    statusText = "Requesting eBird...\nRadius=" + Application.getApp().getProperty("searchRadius") + "km Days=" + Application.getApp().getProperty("daysBack");
                    WatchUi.requestUpdate();
                }
            }
            return;
        }
    }

    // in km
    function getDistanceTo(pointLat, pointLon) {
        var earthRadiusKm = 6371;
        var dLat = Math.toRadians(pointLat-lat);
        var dLon = Math.toRadians(pointLon-lon);
        var lat1 = Math.toRadians(lat);
        var lat2 = Math.toRadians(pointLat);
        var a = Math.sin(dLat/2) * Math.sin(dLat/2) +
                Math.sin(dLon/2) * Math.sin(dLon/2) * Math.cos(lat1) * Math.cos(lat2);
        var c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
        return earthRadiusKm * c;
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() {
        System.println("onShow()");
        onTimer();
    }

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    function onHide() {
    }

}
