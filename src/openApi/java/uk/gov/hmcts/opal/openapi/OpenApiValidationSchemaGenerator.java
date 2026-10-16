package uk.gov.hmcts.opal.openapi;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;
import tools.jackson.databind.node.ObjectNode;
import tools.jackson.dataformat.yaml.YAMLMapper;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;

/** Exports the unchanged bundled components before OpenAPI Generator normalizes them. */
public final class OpenApiValidationSchemaGenerator {

    private OpenApiValidationSchemaGenerator() {
    }

    public static void main(String[] args) throws IOException {
        if (args.length != 3) {
            throw new IllegalArgumentException("Expected bundled input, root component and output file");
        }
        JsonNode bundledDocument = YAMLMapper.builder().build().readTree(new File(args[0]));
        String rootComponent = args[1];
        JsonNode components = bundledDocument.path("components");
        if (!components.path("schemas").has(rootComponent)) {
            throw new IllegalArgumentException("Missing root schema component: " + rootComponent);
        }
        JsonMapper jsonMapper = JsonMapper.builder().build();
        ObjectNode schemaDocument = jsonMapper.createObjectNode();
        schemaDocument.put("$schema", "https://json-schema.org/draft/2020-12/schema");
        schemaDocument.put("$ref", "#/components/schemas/" + rootComponent);
        schemaDocument.set("components", components.deepCopy());
        verifyReferences(schemaDocument, schemaDocument);
        File outputFile = new File(args[2]);
        Files.createDirectories(outputFile.toPath().toAbsolutePath().getParent());
        jsonMapper.writeValue(outputFile, schemaDocument);
    }

    private static void verifyReferences(JsonNode node, JsonNode document) {
        if (node.isObject() && node.has("$ref")) {
            JsonNode reference = node.get("$ref");
            if (!reference.isString() || !reference.asString().startsWith("#/")) {
                throw new IllegalArgumentException("Only local JSON Pointer schema references are supported");
            }
            if (document.at(reference.asString().substring(1)).isMissingNode()) {
                throw new IllegalArgumentException("Unresolved schema reference: " + reference.asString());
            }
        }
        if (node.isContainer()) {
            for (JsonNode child : node) {
                verifyReferences(child, document);
            }
        }
    }
}
