package org.waysidemapping.beefsteak.util;

import org.locationtech.jts.geom.Envelope;
import org.locationtech.jts.geom.Geometry;

import com.carrotsearch.hppc.LongObjectHashMap;
import com.carrotsearch.hppc.LongHashSet;
import com.carrotsearch.hppc.LongLongHashMap;
import com.carrotsearch.hppc.LongIntHashMap;
import com.onthegomap.planetiler.reader.osm.OsmElement;
import java.util.ArrayList;
import java.util.List;

public class RelationMembershipIndex {

  public record Membership(long relationId, String role) {}

  public final LongObjectHashMap<List<Membership>> routeMembershipsByWayId =
    new LongObjectHashMap<>();
  public final LongObjectHashMap<List<Membership>> waterwayMembershipsByWayId =
    new LongObjectHashMap<>();
  public final LongObjectHashMap<List<Membership>> adminBoundaryMembershipsByWayId =
    new LongObjectHashMap<>();
  public final LongObjectHashMap<List<Membership>> nonAdminBoundaryMembershipsByWayId =
    new LongObjectHashMap<>();

  public final LongObjectHashMap<Envelope> relationBboxesById =
    new LongObjectHashMap<>();
  public final LongIntHashMap minZoomsByRelationId =
    new LongIntHashMap();
 
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
        var membership = new Membership(relation.id(), member.role());
        if ("route".equals(tags.get("type"))) {
          addMembership(routeMembershipsByWayId, member.ref(), membership);
        } else if ("waterway".equals(tags.get("type"))) {
          addMembership(waterwayMembershipsByWayId, member.ref(), membership);
        } else if ("administrative".equals(tags.get("boundary"))) {
          addMembership(adminBoundaryMembershipsByWayId, member.ref(), membership);
        } else {
          addMembership(nonAdminBoundaryMembershipsByWayId, member.ref(), membership);
        }
      }
    }
  }

  private void addMembership(LongObjectHashMap<List<Membership>> to, long memberId, Membership membership) {
    var membershipsForWay = to.get(memberId);

    if (membershipsForWay == null) {
      membershipsForWay = new ArrayList<>();
      to.put(memberId, membershipsForWay);
    }
    membershipsForWay.add(membership);
  }

  public Integer minZoomForRelationId(long relationId) {
    if (!minZoomsByRelationId.containsKey(relationId)) {
      var bbox = relationBboxesById.get(relationId);
      if (bbox == null) {
        return null;
      }
      var extent = bbox.getDiameter();
      var minZoomForRelation = minZoomForRelationExtent(extent);
      minZoomsByRelationId.put(relationId, minZoomForRelation);
      return minZoomForRelation;
    }
    return minZoomsByRelationId.get(relationId);
  }

  public void expandRelationBbox(long relationId, Envelope bbox) {
    var relationBbox = relationBboxesById.get(relationId);
    if (relationBbox != null) {
      relationBbox.expandToInclude(bbox);
    } else {
      relationBboxesById.put(relationId, bbox);
    }
  }
  
  private static int minZoomForRelationExtent(double extent3857) {
    return (int) Math.ceil(
      Math.log(0.1875 / extent3857) /
      Math.log(2)
    );
  }

}