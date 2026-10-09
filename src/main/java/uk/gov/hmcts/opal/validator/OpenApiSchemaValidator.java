package uk.gov.hmcts.opal.validator;

import com.networknt.schema.ExecutionConfig;
import com.networknt.schema.ExecutionContext;
import com.networknt.schema.InputFormat;
import com.networknt.schema.Schema;
import com.networknt.schema.SchemaLocation;
import com.networknt.schema.SchemaRegistry;
import com.networknt.schema.SpecificationVersion;
import com.networknt.schema.resource.ClasspathResourceLoader;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Component;
import tools.jackson.core.exc.StreamConstraintsException;
import tools.jackson.core.exc.StreamReadException;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.exc.MismatchedInputException;
import uk.gov.hmcts.opal.common.exception.OpalApiException;
import uk.gov.hmcts.opal.exception.RequestValidationError;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Map;

@Component
public class OpenApiSchemaValidator {

    private final Map<String, Schema> schemas;

    public OpenApiSchemaValidator(@Value("classpath*:openapi-validation/*.json") Resource[] resources)
        throws IOException {
        if (resources.length == 0) {
            throw new IllegalStateException("No generated OpenAPI validation schemas found");
        }
        SchemaRegistry registry = SchemaRegistry.withDefaultDialect(SpecificationVersion.DRAFT_2020_12,
            builder -> builder.resourceLoaders(loaders -> loaders.add(iri -> {
                if ("classpath".equals(iri.getScheme())) {
                    return ClasspathResourceLoader.getInstance().getResource(iri);
                }
                throw new IllegalStateException("External schema resources are not permitted");
            })));
        Schema metaSchema = registry.getSchema(SchemaLocation.of(
            SpecificationVersion.DRAFT_2020_12.getDialectId()));
        metaSchema.initializeValidators();
        Map<String, Schema> compiled = new HashMap<>();
        for (Resource resource : resources) {
            String filename = resource.getFilename();
            if (filename == null || !filename.endsWith(".json")) {
                throw new IllegalStateException("Invalid generated schema resource name");
            }
            String name = filename.substring(0, filename.length() - ".json".length());
            if (compiled.containsKey(name)) {
                throw new IllegalStateException("Duplicate generated schema: " + name);
            }
            String document = resource.getContentAsString(StandardCharsets.UTF_8);
            if (document.isBlank()) {
                throw new IllegalStateException("Empty generated schema: " + name);
            }
            Schema schema = registry.getSchema(document, InputFormat.JSON);
            validateSchemaDocument(metaSchema, schema.getSchemaNode());
            schema.initializeValidators();
            compiled.put(name, schema);
        }
        schemas = Map.copyOf(compiled);
    }

    private static void validateSchemaDocument(Schema metaSchema, JsonNode document) {
        if (!metaSchema.validate(document).isEmpty()) {
            throw new IllegalStateException("Invalid generated JSON Schema");
        }
        // Components is an OpenAPI container, so the meta-schema does not descend into it itself.
        for (JsonNode component : document.path("components").path("schemas")) {
            if (!metaSchema.validate(component).isEmpty()) {
                throw new IllegalStateException("Invalid generated component schema");
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
