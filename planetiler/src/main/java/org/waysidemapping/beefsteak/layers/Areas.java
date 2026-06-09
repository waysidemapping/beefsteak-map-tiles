package org.waysidemapping.beefsteak.layers;

import com.onthegomap.planetiler.FeatureCollector;
import com.onthegomap.planetiler.FeatureMerge;
import com.onthegomap.planetiler.ForwardingProfile.FeatureProcessor;
import com.onthegomap.planetiler.ForwardingProfile.LayerPostProcessor;
import com.onthegomap.planetiler.VectorTile.Feature;
import com.onthegomap.planetiler.geo.GeometryException;
import com.onthegomap.planetiler.reader.SourceFeature;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.waysidemapping.beefsteak.Config;

public class Areas implements FeatureProcessor, LayerPostProcessor {

  private final Config config;

  public Areas(Config config) {
    this.config = config;
  }

  private boolean isInterestingArea(SourceFeature sf) {

    if (!sf.canBePolygon()) {
      return false;
    }

    if (sf.hasTag("advertising") ||
      sf.hasTag("amenity") ||
      sf.hasTag("area:highway") ||
      sf.hasTag("building") ||
      sf.hasTag("building:part") ||
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
      "protected_area".equals(sf.getString("boundary"))) {
      return true;
    }

    Boolean isExplicitArea = !sf.canBeLine() || 
      "yes".equals(sf.getString("area")) ||
      sf.hasTag("building");

    if (isExplicitArea) {
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

  private int minZoom(SourceFeature sf) {

    if (sf.hasTag("building")) {
      return 14;
    }

    if (sf.hasTag("building:part")) {
      return 15;
    }

    if (sf.hasTag("area:highway") || sf.hasTag("indoor") || sf.hasTag("playground")) {
      return 18;
    }

    return 3;
  }

  @Override
  public void processFeature(
    SourceFeature sf,
    FeatureCollector features
  ) {

    if (!isInterestingArea(sf)) {
      return;
    }

    var area = features.polygon("area");

    area.setMinZoom(minZoom(sf));
    copyTags(sf, area);
  }

  private void copyTags(
    SourceFeature sf,
    FeatureCollector.Feature feature
  ) {
    for (var entry : sf.tags().entrySet()) {
      String key = entry.getKey();

      if (config.areaKeys().contains(key) || matchesPrefix(key)) {
        feature.setAttr(key, entry.getValue());
      }
    }
  }

  private boolean matchesPrefix(String key) {
    for (String prefix : config.areaKeyPrefixes()) {
      if (key.startsWith(prefix)) {
        return true;
      }
    }
    return false;
  }

  @Override
  public List<Feature> postProcess(int zoom, List<Feature> items) throws GeometryException {
    if (zoom < 12) {
      List<Feature> itemsWithFilteredTags = new ArrayList<>(items.size());
      for (Feature feature : items) {
        Map<String, Object> filteredTags = new HashMap<>();

        for (String key : config.lowZoomAreaKeys()) {
          Object value = feature.tags().get(key);
          if (value != null) {
            filteredTags.put(key, value);
          }
        }
        itemsWithFilteredTags.add(new Feature(
          feature.layer(),
          feature.id(),
          feature.geometry(),
          filteredTags,
          feature.group()
        ));
      }
      return FeatureMerge.mergeMultiPolygon(itemsWithFilteredTags);
    }
    return items;
  }

  @Override
  public String name() {
    return "area";
  }

}
