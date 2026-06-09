package org.waysidemapping.beefsteak.util;

import org.locationtech.jts.geom.Geometry;
import com.carrotsearch.hppc.LongObjectHashMap;
import com.carrotsearch.hppc.LongHashSet;
import com.carrotsearch.hppc.LongLongHashMap;
import com.onthegomap.planetiler.reader.osm.OsmElement;
import java.util.ArrayList;
import java.util.List;

public class RelationMembershipIndex {

  public record Membership(long relationId, String role) {}

  public final LongObjectHashMap<List<Membership>> membershipsByWayId =
    new LongObjectHashMap<>();
  public final LongObjectHashMap<Geometry> labelNodeGeometriesById = new LongObjectHashMap<>();
  public final LongLongHashMap labelNodeIdsByRelationId = new LongLongHashMap();
  public final LongHashSet labelNodeIds =
    new LongHashSet();

  public void preprocessRelation(OsmElement.Relation relation) {

    var tags = relation.tags();

    boolean isMultiPolygon = "multipolygon".equals(tags.get("type")) ||
      "boundary".equals(tags.get("type"));

    boolean hasInterestingWayMembers =
      "route".equals(tags.get("type")) ||
      "waterway".equals(tags.get("type")) ||
      "administrative".equals(tags.get("boundary")) ||
      "protected_area".equals(tags.get("boundary")) ||
      "aboriginal_lands".equals(tags.get("boundary"));

    if (!isMultiPolygon && !hasInterestingWayMembers) {
      return;
    }

    for (var member : relation.members()) {

      if (member.type() == OsmElement.Type.NODE) {
        if (isMultiPolygon && "label".equals(member.role())) {
          labelNodeIds.add(member.ref());
          labelNodeIdsByRelationId.put(relation.id(), member.ref());
        }
      } else if (member.type() == OsmElement.Type.WAY && hasInterestingWayMembers) {

        var membershipsForWay = membershipsByWayId.get(member.ref());

        if (membershipsForWay == null) {
          membershipsForWay = new ArrayList<>();
          membershipsByWayId.put(member.ref(), membershipsForWay);
        }
        membershipsForWay.add(
          new Membership(
            relation.id(),
            member.role()
          )
        );
      }
    }
  }

}