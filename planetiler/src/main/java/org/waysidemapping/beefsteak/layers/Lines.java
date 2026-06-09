package org.waysidemapping.beefsteak.layers;

import com.onthegomap.planetiler.FeatureCollector;
import com.onthegomap.planetiler.ForwardingProfile.FeatureProcessor;
import com.onthegomap.planetiler.reader.SourceFeature;
import org.waysidemapping.beefsteak.util.RelationMembershipIndex;
import org.waysidemapping.beefsteak.Config;
import java.util.Set;

public class Lines implements FeatureProcessor {

  private final Config config;
  private final RelationMembershipIndex relationIndex;

  public Lines(Config config, RelationMembershipIndex relationIndex) {
    this.config = config;
    this.relationIndex = relationIndex;
  }

  private static final Set<String> roadHighwayTagValues = Set.of(
    "motorway",
    "motorway_link",
    "trunk",
    "trunk_link",
    "primary",
    "primary_link",
    "secondary",
    "secondary_link",
    "tertiary",
    "tertiary_link",
    "residential",
    "unclassified",
    "pedestrian"
  );

  private boolean isInterestingLine(SourceFeature sf) {

    if (!sf.canBeLine()) {
      return false;
    }

    if (sf.hasTag("aerialway") ||
      sf.hasTag("aeroway") ||
      sf.hasTag("barrier") ||
      sf.hasTag("highway") ||
      sf.hasTag("power") ||
      sf.hasTag("railway") ||
      sf.hasTag("route") ||
      sf.hasTag("telecom") ||
      sf.hasTag("waterway")) {
      return true;
    }

    if ("coastline".equals(sf.getString("natural"))) {
      return true;
    }

    Boolean isExplicitLine = !sf.canBePolygon() || "no".equals(sf.getString("area"));
    if (isExplicitLine) {
      if (sf.hasTag("golf") ||
        sf.hasTag("indoor") ||
        sf.hasTag("man_made") ||
        sf.hasTag("natural")) {
        return true;
      }
    }
    
    return false;
  }

  private int minZoom(SourceFeature sf) {

    if (sf.hasTag("highway")) {
      String highway = sf.getString("highway");
      if (roadHighwayTagValues.contains(highway)) {
        return 12;
      }
      if (!"footway".equals(highway) || !sf.hasTag("footway")) {
        return 13;
      }
      return 15;
    }

    if (sf.hasTag("golf")) {
      return 15;
    }

    if (sf.hasTag("indoor")) {
      return 18;
    }

    return 12;
  }
  @Override
  public void processFeature(
    SourceFeature sf,
    FeatureCollector features
  ) {

    if (!isInterestingLine(sf)) {
      return;
    }

    var line = features.line("line");

    line.setMinZoom(minZoom(sf));
    copyTags(sf, line);

    var rels = relationIndex.membershipsByWayId.get(sf.id());

    if (rels != null) {
      for (var rel : rels) {
        line.setAttr(
          "m." + rel.relationId(),
          rel.role()
        );
      }
    }
  }

  private void copyTags(
    SourceFeature sf,
    FeatureCollector.Feature feature
  ) {
    for (var entry : sf.tags().entrySet()) {
      String key = entry.getKey();

      if (config.lineKeys().contains(key) || matchesPrefix(key)) {
        feature.setAttr(key, entry.getValue());
      }
    }
  }

  private boolean matchesPrefix(String key) {
    for (String prefix : config.lineKeyPrefixes()) {
      if (key.startsWith(prefix)) {
        return true;
      }
    }
    return false;
  }

}
