package org.waysidemapping.beefsteak.util;

import java.io.BufferedReader;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.HashSet;
import java.util.Set;

public final class NewlineSeparatedFileSetLoader {

  private NewlineSeparatedFileSetLoader() {}
  public static Set<String> loadSet(Path file) {
    Set<String> result = new HashSet<>();

    try (BufferedReader br = Files.newBufferedReader(file)) {
      String line;
      while ((line = br.readLine()) != null) {
        line = line.trim();
        if (!line.isEmpty()) {
          result.add(line);
        }
      }
    } catch (IOException e) {
      throw new RuntimeException("Failed to load " + file, e);
    }

    return Set.copyOf(result);
  }
}