package uk.gov.hmcts.opal.validator;

import com.networknt.schema.ExecutionConfig;
import com.networknt.schema.ExecutionContext;
import com.networknt.schema.InputFormat;
import com.networknt.schema.Schema;
import com.networknt.schema.SchemaLocation;
import com.networknt.schema.SchemaRegistry;
import com.networknt.schema.SpecificationVersion;
import com.networknt.schema.dialect.Dialect;
import com.networknt.schema.dialect.Dialects;
import com.networknt.schema.keyword.AnnotationKeyword;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Component;
import tools.jackson.core.exc.StreamConstraintsException;
import tools.jackson.core.exc.StreamReadException;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.exc.MismatchedInputException;
import tools.jackson.dataformat.yaml.YAMLMapper;
import uk.gov.hmcts.opal.common.exception.OpalApiException;
import uk.gov.hmcts.opal.exception.RequestValidationError;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Map;

@Component
public class OpenApiSchemaValidator {

    private static final String BUNDLE_LOCATION = "urn:opal:openapi-bundled.yaml";

    private final Map<String, Schema> schemas;

    public OpenApiSchemaValidator(@Value("classpath*:openapi-bundled.yaml") Resource[] resources)
        throws IOException {
        if (resources.length != 1) {
            throw new IllegalStateException("Exactly one bundled OpenAPI document is required");
        }
        JsonNode document = YAMLMapper.builder().build().readTree(
            resources[0].getContentAsString(StandardCharsets.UTF_8));
        if (document == null || !document.path("openapi").asString("").startsWith("3.1.")) {
            throw new IllegalStateException("An OpenAPI 3.1 document is required");
        }
        JsonNode components = document.path("components").path("schemas");
        if (!components.isObject() || components.isEmpty()) {
            throw new IllegalStateException("No bundled OpenAPI schemas found");
        }
        verifyReferences(document, document);

        // NetworkNT 3.0.8 inspects the containing document when resolving a schema fragment.
        // Recognise its metadata without suppressing diagnostics for other unknown keywords.
        // Remove these additions when the fix for networknt/json-schema-validator#1205 is released.
        Dialect dialect = Dialect.builder(Dialects.getOpenApi31())
            .keyword(new AnnotationKeyword("openapi"))
            .keyword(new AnnotationKeyword("info"))
            .keyword(new AnnotationKeyword("paths"))
            .keyword(new AnnotationKeyword("components"))
            .build();
        SchemaRegistry registry = SchemaRegistry.withDialect(dialect,
            builder -> builder.resourceLoaders(loaders -> loaders.add(iri -> {
                if (BUNDLE_LOCATION.equals(iri.toString())) {
                    return resources[0]::getInputStream;
                }
                throw new IllegalStateException("External schema resources are not permitted");
            })));
        Schema metaSchema = SchemaRegistry.withDefaultDialect(SpecificationVersion.DRAFT_2020_12)
            .getSchema(SchemaLocation.of(SpecificationVersion.DRAFT_2020_12.getDialectId()));
        metaSchema.initializeValidators();
        Map<String, Schema> compiled = new HashMap<>();
        for (Map.Entry<String, JsonNode> component : components.properties()) {
            if (!metaSchema.validate(component.getValue()).isEmpty()) {
                throw new IllegalStateException("Invalid bundled OpenAPI schema: " + component.getKey());
            }
            String pointerName = component.getKey().replace("~", "~0").replace("/", "~1");
            Schema schema = registry.getSchema(SchemaLocation.of(
                BUNDLE_LOCATION + "#/components/schemas/" + pointerName));
            schema.initializeValidators();
            compiled.put(component.getKey(), schema);
        }
        schemas = Map.copyOf(compiled);
    }

    private static void verifyReferences(JsonNode node, JsonNode document) {
        if (node.isObject() && node.has("$ref")) {
            JsonNode reference = node.get("$ref");
            if (!reference.isString() || !reference.asString().startsWith("#/")) {
                throw new IllegalStateException("Only local OpenAPI schema references are permitted");
            }
            if (document.at(reference.asString().substring(1)).isMissingNode()) {
                throw new IllegalStateException("Unresolved OpenAPI schema reference");
            }
        }
        if (node.isContainer()) {
            for (JsonNode child : node) {
                verifyReferences(child, document);
            }
        }
    }

    public void validate(String schemaName, byte[] body) {
        Schema schema = schemas.get(schemaName);
        if (schema == null) {
            throw new IllegalStateException("Unknown OpenAPI request schema: " + schemaName);
        }
        ExecutionContext context = new ExecutionContext(
            ExecutionConfig.builder().formatAssertionsEnabled(true).build());
        try {
            if (!schema.validate(context, new String(body, StandardCharsets.UTF_8), InputFormat.JSON).isEmpty()) {
                throw invalidRequest();
            }
        } catch (StreamReadException | StreamConstraintsException | MismatchedInputException exception) {
            // Parser diagnostics can contain submitted values, so do not attach the cause.
            throw invalidRequest();
        }
    }

    private static OpalApiException invalidRequest() {
        return new OpalApiException(RequestValidationError.INVALID_REQUEST,
            "Request body does not match the API contract");
    }
}
