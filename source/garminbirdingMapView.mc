using Toybox.WatchUi;
using Toybox.Position;
using Toybox.System;

class HotspotMapView extends WatchUi.MapView {

    function initialize(lat, lon, radius, hotspotPosition, hotspotName, screenWidth, screenHeight) {
        WatchUi.MapView.initialize();

        // create a marker for the location
        var curPos = new Position.Location({
            :latitude => lat,
            :longitude => lon,
            :format => :degrees,
        });
        var hotspot = hotspotPosition.toDegrees();
        var marker = new WatchUi.MapMarker(hotspotPosition);
        marker.setLabel(hotspotName);

        // determine top left
        // 1 degree latitude = 111km
        var latOffset = radius/111.0;
        var lonOffset = radius/(Math.cos(Math.toRadians(lat)).abs() * 111.0);
        System.println("Offset lat:" + latOffset + ",lon:" + lonOffset);
        var leftLon = lon - lonOffset;
        if (leftLon < -180) {
            leftLon = 360 - leftLon;
        }
        var rightLon = lon + lonOffset;
        if (rightLon > 180) {
            rightLon = rightLon - 360;
        }
//        System.println("Show map with radius:" + radius + "km, current location:" + lat + "," + lon);
//        System.println("Hotspot Loc:" + hotspot[0] + "," + hotspot[1]);
//        System.println("Top Left:" + (lat + latOffset) + "," + leftLon);
//        System.println("Bottom Right:" + (lat - latOffset) + "," + rightLon);

        // map visible area
        var top_left = new Position.Location({:latitude => lat + latOffset, :longitude => leftLon, :format => :degrees});
        var bottom_right = new Position.Location({:latitude => lat - latOffset, :longitude => rightLon, :format => :degrees});
        MapView.setMapVisibleArea(top_left, bottom_right);
        MapView.setScreenVisibleArea(0, 0, screenWidth, screenHeight);
        // Set the map mode
        MapView.setMapMode(WatchUi.MAP_MODE_BROWSE);
        // Set the location marker
        MapView.setMapMarker([marker]);
    }
}