package uk.gov.hmcts.opal.openapi;

import tools.jackson.databind.ObjectMapper;
import tools.jackson.dataformat.yaml.YAMLFactory;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

public class OpenApiBundler {

    private static final ObjectMapper mapper = new ObjectMapper(new YAMLFactory());

    private static final Set<String> SHARED_COMPONENT_FILES = Set.of("common", "types");

    private OpenApiBundler() {

    }

    // All OpenAPI component sections that can contain $ref targets
    private static final List<String> COMPONENT_SECTIONS = List.of(
        "schemas", "responses", "parameters", "headers",
        "requestBodies", "examples", "links", "callbacks", "securitySchemes", "pathItems"
    );

    @SuppressWarnings("unchecked")
    public static void main(String[] args) throws IOException {
        if (args.length < 2) {
            System.err.println("Usage: OpenApiBundler <inputDir> <outputFile>");
            System.exit(1);
        }

        final Path inputDir = Paths.get(args[0]);
        final Path outputFile = Paths.get(args[1]);

        Map<String, Object> bundled = new LinkedHashMap<>();
        bundled.put("openapi", "3.1.1");
        bundled.put("info", Map.of("title", "Bundled API", "version", "1.0.0"));
        bundled.put("paths", new LinkedHashMap<>());
        Map<String, Object> bundledComponents = new LinkedHashMap<>();
        bundled.put("components", bundledComponents);

        // Pre-create empty maps for known component sections
        for (String section : COMPONENT_SECTIONS) {
            bundledComponents.put(section, new LinkedHashMap<String, Object>());
        }

        Files.list(inputDir)
            .filter(f -> f.toString().endsWith(".yaml"))
            .sorted() // deterministic
            .forEach(file -> {
                try {
                    Map<String, Object> yaml = mapper.readValue(file.toFile(), Map.class);
                    String fileName = stripYaml(file.getFileName().toString());
                    String prefix = componentPrefix(fileName);

                    // Merge paths (rewrite local & cross-file refs)
                    Map<String, Object> paths = (Map<String, Object>) yaml.get("paths");
                    if (paths != null) {
                        paths.replaceAll((k, v) -> rewriteRefs(v, prefix));
                        ((Map<String, Object>) bundled.get("paths")).putAll(paths);
                    }

                    // Merge all component sections, prefixing resource-specific names with the file name.
                    Map<String, Object> components = (Map<String, Object>) yaml.get("components");
                    if (components != null) {
                        for (String section : COMPONENT_SECTIONS) {
                            Map<String, Object> src = (Map<String, Object>) components.get(section);
                            if (src == null) {
                                continue;
                            }

                            Map<String, Object> dst = getOrCreateSection(bundledComponents, section);
                            for (Map.Entry<String, Object> e : src.entrySet()) {
                                String oldName = e.getKey();
                                String newName = qualifyComponentName(oldName, prefix);
                                Object valueWithRewrites = rewriteRefs(e.getValue(), prefix);

                                if (dst.containsKey(newName)) {
                                    // You can choose to overwrite, skip, or fail. Failing is safest.
                                    throw new IllegalStateException(
                                        "Name collision in components/" + section + ": " + newName + " (from "
                                            + file.getFileName() + ")"
                                    );
                                }
                                dst.put(newName, valueWithRewrites);
                            }
                        }
                    }

                } catch (Exception e) {
                    throw new RuntimeException("While processing " + file.getFileName() + ": " + e.getMessage(), e);
                }
            });

        mapper.writeValue(outputFile.toFile(), bundled);
    }

    @SuppressWarnings("unchecked")
    private static Object rewriteRefs(Object node, String currentPrefix) {
        if (node instanceof Map) {
            Map<String, Object> map = new LinkedHashMap<>((Map<String, Object>) node);

            Object refVal = map.get("$ref");
            if (refVal instanceof String ref) {
                // Case 1: external file reference: ./file.yaml#/components/<section>/<name>[...]
                if (ref.startsWith("./")) {
                    String[] fileAndPath = ref.split("#", 2);
                    String fileName = stripYaml(new File(fileAndPath[0]).getName());
                    String prefix = componentPrefix(fileName);

                    if (fileAndPath.length == 2 && fileAndPath[1].startsWith("/components/")) {
                        String componentPath = fileAndPath[1].replaceFirst("^/components/", "");
                        map.put("$ref", "#/components/" + qualifyLastSegment(componentPath, prefix));
                    }
                    // Case 2: local reference: #/components/<section>/<name>[...]
                } else if (ref.startsWith("#/components/")) {
                    String componentPath = ref.replaceFirst("^#/components/", "");
                    map.put("$ref", "#/components/" + qualifyLastSegment(componentPath, currentPrefix));
                }
            }

            // Recurse
            map.replaceAll((k, v) -> rewriteRefs(v, currentPrefix));
            return map;
        } else if (node instanceof List) {
            List<Object> list = new ArrayList<>();
            for (Object item : (List<Object>) node) {
                list.add(rewriteRefs(item, currentPrefix));
            }
            return list;
        }
        return node;
    }

    // Qualify only the component name, retaining its section and any trailing JSON Pointer.
    // For example, "schemas/ReferenceDataItem/allOf/0" becomes
    // "schemas/ResultReferenceDataItem/allOf/0" for components declared in Result.yaml.
    private static String qualifyLastSegment(String componentPath, String prefix) {
        int slash = componentPath.indexOf('/'); // first slash after section
        if (slash < 0) {
            return componentPath; // malformed; don't touch
        }

        String section = componentPath.substring(0, slash);
        String rest = componentPath.substring(slash + 1);

        // Split rest at the next '/' to isolate the component name
        int next = rest.indexOf('/');
        String name = (next == -1) ? rest : rest.substring(0, next);
        String tail = (next == -1) ? "" : rest.substring(next); // includes the '/'

        String qualifiedName = qualifyComponentName(name, prefix);
        return section + "/" + qualifiedName + tail;
    }

    private static String componentPrefix(String fileName) {
        return SHARED_COMPONENT_FILES.contains(fileName.toLowerCase()) ? "" : capitalize(fileName);
    }

    private static String qualifyComponentName(String name, String prefix) {
        boolean alreadyQualified = !prefix.isEmpty()
            && name.regionMatches(true, 0, prefix, 0, prefix.length())
            && (name.length() == prefix.length()
                || name.length() > prefix.length() && Character.isUpperCase(name.charAt(prefix.length())));
        if (prefix.isEmpty() || alreadyQualified) {
            return name;
        }
        return prefix + capitalize(name);
    }

    private static String stripYaml(String fileName) {
        return fileName.endsWith(".yaml") ? fileName.substring(0, fileName.length() - 5) : fileName;
    }

    private static String capitalize(String s) {
        if (s == null || s.isEmpty()) {
            return s;
        }
        return s.substring(0, 1).toUpperCase() + s.substring(1);
    }

    @SuppressWarnings("unchecked")
    private static Map<String, Object> getOrCreateSection(Map<String, Object> components, String section) {
        return (Map<String, Object>) components.computeIfAbsent(section, k -> new LinkedHashMap<>());
    }
}
