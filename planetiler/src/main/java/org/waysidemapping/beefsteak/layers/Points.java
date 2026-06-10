package org.waysidemapping.beefsteak.layers;

import com.onthegomap.planetiler.FeatureCollector;
import com.onthegomap.planetiler.ForwardingProfile.FeatureProcessor;
import com.onthegomap.planetiler.geo.GeometryException;
import com.onthegomap.planetiler.reader.SourceFeature;
import com.onthegomap.planetiler.reader.osm.OsmElement;
import com.onthegomap.planetiler.reader.osm.OsmSourceFeature;

import org.waysidemapping.beefsteak.util.RelationMembershipIndex;
import org.waysidemapping.beefsteak.Config;

public class Points implements FeatureProcessor {

  private final Config config;
  private final RelationMembershipIndex relationIndex;

  public Points(Config config, RelationMembershipIndex relationIndex) {
    this.config = config;
    this.relationIndex = relationIndex;
  }

  private boolean isInterestingPoint(SourceFeature sf) {

    if (!sf.isPoint() && !sf.canBePolygon()) {
      return false;
    }

    if (isInterestingAsNotBuilding(sf)) {
      return true;
    }

    if (sf.hasTag("building")) {
      return true;
    }
    
    return false;
  }

  private int minZoomBasedOnTags(SourceFeature sf) {
    if ("continent".equals(sf.getString("place")) ||
      "ocean".equals(sf.getString("place"))) {
      return 0;
    }
    if ("sea".equals(sf.getString("place")) ||
      "country".equals(sf.getString("place"))) {
      return 3;
    }
    if ("city".equals(sf.getString("place"))) {
      return 4;
    }
    if ("town".equals(sf.getString("place"))) {
      return 6;
    }
    if ("village".equals(sf.getString("place"))) {
      return 7;
    }
    if ("hamlet".equals(sf.getString("place")) ||
        "peak".equals(sf.getString("natural")) ||
        "volcano".equals(sf.getString("natural"))) {
      return 8;
    }
    if ("locality".equals(sf.getString("place")) ||
        "station".equals(sf.getString("public_transport")) ||
        "aerodrome".equals(sf.getString("aeroway")) ||
        "motorway_junction".equals(sf.getString("highway"))) {
      return 9;
    }

    if (sf.hasTag("building")) {
      if (!isInterestingAsNotBuilding((sf)) &&
        !sf.hasTag("name") &&
        !sf.hasTag("wikidata")) {
        return 15;
      }
    }
    
    return 12;
  }

  @Override
  public void processFeature(
    SourceFeature sf,
    FeatureCollector features
  ) {

    if (sf.isPoint() && relationIndex.labelNodeIds.contains(sf.id())) {
      try {
        // we can cache geometry here to use for relations later since all nodes are processed before any relations
        relationIndex.labelNodeGeometriesById.put(sf.id(), sf.worldGeometry());
      } catch (GeometryException e) {
        // ignore error
      }
    }

    if (!isInterestingPoint(sf)) {
      return;
    }

    FeatureCollector.Feature point = null;

    if (sf instanceof OsmSourceFeature osmSourceFeature &&
        osmSourceFeature.originalElement().type() == OsmElement.Type.RELATION &&
        relationIndex.labelNodeIdsByRelationId.containsKey(sf.id())) {
      
      var labelNodeId = relationIndex.labelNodeIdsByRelationId.get(sf.id());
      var pointGeom = relationIndex.labelNodeGeometriesById.get(labelNodeId);
      if (pointGeom != null) {
        point = features.geometry("point", pointGeom);
      }
    }
    if (point == null) {
      point = features.centroidIfConvex("point");
    }

    var minZoom = minZoomBasedOnTags(sf);

    if (sf.canBePolygon()) {
      try {
        var area3857 = sf.area() * 4 * 20037508.3427892 * 20037508.3427892;

        var minZoomForArea = minZoomGivenArea(area3857);

        if (minZoomForArea < minZoom) {
          minZoom = minZoomForArea;
        }
        
        point.setMaxZoom(maxZoomGivenArea(area3857));

        if (area3857 >= 1) {
          if (area3857 <= 1000) { 
            area3857 = roundSigFigs(area3857, 1);
          } else if (area3857 <= 1000000) { 
            area3857 = roundSigFigs(area3857, 2);
          } else {
            area3857 = roundSigFigs(area3857, 3);
          }
          point.setAttr("c.area", area3857);
        }
      } catch (GeometryException e) {
        // ignore
      }
    }

    point.setMinZoom(minZoom);
    copyTags(sf, point);
  }

  static double roundSigFigs(double x, int sigFigs) {
    if (x == 0 || !Double.isFinite(x)) return x;

    double scale = Math.pow(10, sigFigs - 1 - Math.floor(Math.log10(Math.abs(x))));
    return Math.round(x * scale) / scale;
  }

  private void copyTags(
    SourceFeature sf,
    FeatureCollector.Feature feature
  ) {
    for (var entry : sf.tags().entrySet()) {
      String key = entry.getKey();

      if (config.pointKeys().contains(key) || matchesPrefix(key)) {
        feature.setAttr(key, entry.getValue());
      }
    }
  }

  private boolean matchesPrefix(String key) {
    for (String prefix : config.pointKeyPrefixes()) {
      if (key.startsWith(prefix)) {
        return true;
      }
    }
    return false;
  }

  private boolean isInterestingAsNotBuilding(SourceFeature sf) {

    if (sf.hasTag("advertising") ||
      sf.hasTag("amenity") ||
      sf.hasTag("club") ||
      sf.hasTag("craft") ||
      sf.hasTag("education") ||
      sf.hasTag("emergency") ||
      sf.hasTag("golf") ||
      sf.hasTag("healthcare") ||
      sf.hasTag("indoor") ||
      sf.hasTag("information") ||
      sf.hasTag("landuse") ||
      sf.hasTag("leisure") ||
      sf.hasTag("man_made") ||
      sf.hasTag("military") ||
      sf.hasTag("office") ||
      sf.hasTag("place") ||
      sf.hasTag("playground") ||
      sf.hasTag("public_transport") ||
      sf.hasTag("shop") ||
      sf.hasTag("tourism")) {
      return true;
    }

    if (sf.hasTag("natural") && !"coastline".equals(sf.getString("natural"))) {
      return true;
    }

    if ("aboriginal_lands".equals(sf.getString("boundary")) ||
      "administrative".equals(sf.getString("boundary")) ||
      "protected_area".equals(sf.getString("boundary"))) {
      return true;
    }
    
    Boolean isNodeOrExplicitArea = !sf.canBeLine() || 
      "yes".equals(sf.getString("area")) ||
      sf.hasTag("building");

    if (isNodeOrExplicitArea) {
      if (sf.hasTag("aerialway") ||
        sf.hasTag("aeroway") ||
        sf.hasTag("barrier") ||
        sf.hasTag("highway") ||
        sf.hasTag("power") ||
        sf.hasTag("railway") ||
        sf.hasTag("telecom") ||
        sf.hasTag("waterway")) {
        return true;
      }
    }
    return false;
  }

  static int minZoomGivenArea(double area) {
    double W0 = 20037508.3427892 * 2;
    return (int) Math.ceil(Math.log(W0 / (32.0 * Math.sqrt(area))) / Math.log(2));
  }

  static int maxZoomGivenArea(double area) {
    double W0 = 20037508.3427892 * 2;
    return (int) Math.floor(Math.log(4.0 * W0 / Math.sqrt(area)) / Math.log(2));
  }

}
