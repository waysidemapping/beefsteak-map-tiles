package org.waysidemapping.beefsteak;

import org.waysidemapping.beefsteak.util.NewlineSeparatedFileSetLoader;

import java.nio.file.Path;
import java.util.Set;

public record Config (
  Set<String> lowZoomAreaKeys,
  Set<String> areaKeyPrefixes,
  Set<String> areaKeys,
  Set<String> lowZoomLineKeys,
  Set<String> lineKeyPrefixes,
  Set<String> lineKeys,
  Set<String> pointKeyPrefixes,
  Set<String> pointKeys,
  Set<String> relationKeyPrefixes,
  Set<String> relationKeys
){

  public static Config load(Path dir) {
    return new Config(
      NewlineSeparatedFileSetLoader.loadSet(dir.resolve("area_key_low_zoom.txt")),
      NewlineSeparatedFileSetLoader.loadSet(dir.resolve("area_key_prefix.txt")),
      NewlineSeparatedFileSetLoader.loadSet(dir.resolve("area_key.txt")),
      NewlineSeparatedFileSetLoader.loadSet(dir.resolve("line_key_low_zoom.txt")),
      NewlineSeparatedFileSetLoader.loadSet(dir.resolve("line_key_prefix.txt")),
      NewlineSeparatedFileSetLoader.loadSet(dir.resolve("line_key.txt")),
      NewlineSeparatedFileSetLoader.loadSet(dir.resolve("point_key_prefix.txt")),
      NewlineSeparatedFileSetLoader.loadSet(dir.resolve("point_key.txt")),
      NewlineSeparatedFileSetLoader.loadSet(dir.resolve("relation_key_prefix.txt")),
      NewlineSeparatedFileSetLoader.loadSet(dir.resolve("relation_key.txt"))
    );
  }

}