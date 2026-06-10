package org.waysidemapping.beefsteak.layers;

import com.carrotsearch.hppc.LongObjectHashMap;
import com.onthegomap.planetiler.FeatureCollector;
import com.onthegomap.planetiler.FeatureMerge;
import com.onthegomap.planetiler.ForwardingProfile.FeatureProcessor;
import com.onthegomap.planetiler.ForwardingProfile.LayerPostProcessor;
import com.onthegomap.planetiler.VectorTile.Feature;
import com.onthegomap.planetiler.geo.GeometryException;
import com.onthegomap.planetiler.reader.SourceFeature;

import org.waysidemapping.beefsteak.util.RelationMembershipIndex;
import org.waysidemapping.beefsteak.util.RelationMembershipIndex.Membership;
import org.waysidemapping.beefsteak.Config;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

public class Lines implements FeatureProcessor, LayerPostProcessor {

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

    if (relationIndex.routeMembershipsByWayId.containsKey(sf.id()) ||
      relationIndex.waterwayMembershipsByWayId.containsKey(sf.id()) ||
      relationIndex.adminBoundaryMembershipsByWayId.containsKey(sf.id()) ||
      relationIndex.nonAdminBoundaryMembershipsByWayId.containsKey(sf.id())) {
      return true;
    }
    
    return false;
  }

  private int minZoom(SourceFeature sf) {
    if (sf.hasTag("golf")) {
      return 15;
    }
    if (sf.hasTag("indoor")) {
      return 18;
    }
    return 3;
  }

  @Override
  public void processFeature(
    SourceFeature sf,
    FeatureCollector features
  ) {

    if (!isInterestingLine(sf)) {
      return;
    }

    if (relationIndex.routeMembershipsByWayId.containsKey(sf.id()) ||
      relationIndex.waterwayMembershipsByWayId.containsKey(sf.id())) {
      try {
        var wayBbox = sf.worldGeometry().getEnvelopeInternal();
        var memberships = relationIndex.routeMembershipsByWayId.get(sf.id());
        if (memberships != null) {
          for (var membership : memberships) {
            relationIndex.expandRelationBbox(membership.relationId(), wayBbox);
          }
        }
        memberships = relationIndex.waterwayMembershipsByWayId.get(sf.id());
        if (memberships != null) {
          for (var membership : memberships) {
            relationIndex.expandRelationBbox(membership.relationId(), wayBbox);
          }
        }
      } catch (GeometryException e) {
        // ignore
      }
    }

    var line = features.line("line");
    line.setMinPixelSize(0);
    line.setMinZoom(minZoom(sf));
    copyTags(sf, line);
    copyRelationMemberships(sf, line, relationIndex.routeMembershipsByWayId);
    copyRelationMemberships(sf, line, relationIndex.waterwayMembershipsByWayId);
    copyRelationMemberships(sf, line, relationIndex.adminBoundaryMembershipsByWayId);
    copyRelationMemberships(sf, line, relationIndex.nonAdminBoundaryMembershipsByWayId);
  }

  private void copyRelationMemberships(
    SourceFeature sf,
    FeatureCollector.Feature feature,
    LongObjectHashMap<List<Membership>> membershipsByWayId
  ) {
    var rels = membershipsByWayId.get(sf.id());
    if (rels != null) {
      for (var rel : rels) {
        feature.setAttr(
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

  @Override
  public List<Feature> postProcess(int zoom, List<Feature> items) throws GeometryException {
    
    List<Feature> result = new ArrayList<>();
    if (zoom < 12) {
      for (Feature feature : items) {
        var relevantRelationKeys = getRelevantRelationKeys(zoom, feature);
        if (relevantRelationKeys.size() > 0) {
          result.add(new Feature(
            feature.layer(),
            feature.id(),
            feature.geometry(),
            filterTagsForLowZoom(feature.tags(), relevantRelationKeys),
            feature.group()
          ));
        }
      }
      return FeatureMerge.mergeLineStrings(result, 0.5, 0.5, 4, true);
    }

    for (Feature feature : items) {
      var relevantRelationKeys = getRelevantRelationKeys(zoom, feature);
      if (relevantRelationKeys.size() > 0 || minZoomForPostProcess(feature) <= zoom) {
        result.add(new Feature(
          feature.layer(),
          feature.id(),
          feature.geometry(),
          filterTagsForHighZoom(feature.tags(), relevantRelationKeys),
          feature.group()
        ));
      }
    }

    return result;
  }

  private  Set<String> getRelevantRelationKeys(int zoom, Feature feature) {
    Set<String> relevantRelationKeys = new HashSet<>();
    var wayId = feature.id() / 10; // strip OSM type digit
    var routeMemberships = relationIndex.routeMembershipsByWayId.get(wayId);
    if (routeMemberships != null) {
      for (Membership membership : routeMemberships) {
        var minZoomForRelation = relationIndex.minZoomForRelationId(membership.relationId());
        if (minZoomForRelation != null && minZoomForRelation <= zoom) {
          relevantRelationKeys.add("m." + membership.relationId());    
        }
      }
    }
    var waterwayMemberships = relationIndex.waterwayMembershipsByWayId.get(wayId);
    if (waterwayMemberships != null) {
      for (Membership membership : waterwayMemberships) {
        if ("main_stream".equals(membership.role())) {
          var minZoomForRelation = relationIndex.minZoomForRelationId(membership.relationId());
          if (minZoomForRelation != null && minZoomForRelation <= zoom) {
            relevantRelationKeys.add("m." + membership.relationId());    
          }
        }
      }
    }
    return relevantRelationKeys;
  }

  private long minZoomForPostProcess(Feature feature) {
    if (feature.hasTag("highway")) {
      String highway = feature.getString("highway");
      if (roadHighwayTagValues.contains(highway)) {
        return 12;
      }
      if (!"footway".equals(highway) || !feature.hasTag("footway")) {
        return 13;
      }
      return 15;
    }
    return 12;
  }

  private Map<String, Object> filterTagsForLowZoom(Map<String, Object> tags, Set<String> keepRelationKeys) {
    Map<String, Object> filteredTags = new HashMap<>();
    for (String key : tags.keySet()) {
      if (config.lowZoomLineKeys().contains(key) ||
        keepRelationKeys.contains(key)) {
        filteredTags.put(key, tags.get(key));
      }
    }
    return filteredTags;
  }

  private Map<String, Object> filterTagsForHighZoom(Map<String, Object> tags, Set<String> keepRelationKeys) {
    Map<String, Object> filteredTags = new HashMap<>();
    for (String key : tags.keySet()) {
      if (!key.startsWith("m.") ||
        keepRelationKeys.contains(key)) {
        filteredTags.put(key, tags.get(key));
      }
    }
    return filteredTags;
  }

  @Override
  public String name() {
    return "line";
  }

}
