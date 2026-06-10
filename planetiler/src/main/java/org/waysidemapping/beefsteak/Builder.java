package org.waysidemapping.beefsteak;

import com.onthegomap.planetiler.ForwardingProfile;
import com.onthegomap.planetiler.Planetiler;
import com.onthegomap.planetiler.config.Arguments;
import com.onthegomap.planetiler.reader.osm.OsmElement;
import com.onthegomap.planetiler.reader.osm.OsmRelationInfo;

import org.waysidemapping.beefsteak.util.RelationMembershipIndex;
import org.waysidemapping.beefsteak.layers.Areas;
import org.waysidemapping.beefsteak.layers.Lines;
import org.waysidemapping.beefsteak.layers.Points;

import java.io.IOException;
import java.nio.file.Path;
import java.util.List;

public class Builder extends ForwardingProfile {

  private final RelationMembershipIndex relationIndex =
    new RelationMembershipIndex();

  @Override
  public List<OsmRelationInfo> preprocessOsmRelation(OsmElement.Relation relation) {
    relationIndex.preprocessRelation(relation);
    return null;
  }

  public Builder(Config config) {
    var layers = List.of(
      new Points(config, relationIndex),
      new Lines(config, relationIndex),
      new Areas(config)
    );

    for (var layer : layers) {
      registerHandler(layer);
    }
  }

  @Override
  public String name() {
    return "Beefsteak Tiles";
  }

  @Override
  public String description() {
    return "Server-farm-to-table OpenStreetMap tiles";
  }

  @Override
  public String version() {
    return "0.0.1";
  }

  @Override
  public boolean isOverlay() {
    return false;
  }

  @Override
  public String attribution() {
    return "Map data from <a href='https://www.openstreetmap.org/copyright' target='_blank'>OpenStreetMap</a>";
  }

  public static void main(String[] args) throws IOException {
    run(Arguments.fromArgsOrConfigFile(args));
  }

  static void run(Arguments args) throws IOException {
    args = args.orElse(Arguments.of("maxzoom", 16));
    String area = args.getString("area", "geofabrik area to download", "rhode-island");

    var planetiler = Planetiler.create(args)
      .addOsmSource("osm", Path.of("data", "sources", area + ".osm.pbf"), "geofabrik:" + area);

    Path schemaDir = Path.of(
        args.getString(
        "schema-dir",
        "directory containing tagging schema data files",
        "../server/schema_data"
      )
    );
    Config config = Config.load(schemaDir);

    planetiler.setProfile(new Builder(config)).setOutput("data/beefsteak.pmtiles").run();
  }
}
