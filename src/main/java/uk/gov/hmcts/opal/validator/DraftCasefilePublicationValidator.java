package uk.gov.hmcts.opal.validator;

import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import tools.jackson.core.JacksonException;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;
import uk.gov.hmcts.opal.generated.model.CasefileType;

import java.nio.charset.StandardCharsets;

@Component
@RequiredArgsConstructor
public class DraftCasefilePublicationValidator {
    private final OpenApiSchemaValidator schemas;
    private final DraftCasefileValidator casefiles;
    private final ObjectMapper json;

    public JsonNode validate(DraftCasefileEntity draft) {
        if (blank(draft.getSubmittedBy()) || blank(draft.getSubmittedByName())
            || blank(draft.getValidatedBy()) || blank(draft.getValidatedByName())
            || draft.getValidatedDate() == null || draft.getSubmittedBy().equals(draft.getValidatedBy())
            || draft.getCasefile() == null || draft.getCasefileSnapshot() == null) {
            throw new IllegalStateException("Invalid saved publication data");
        }
        schemas.validate("Casefile", draft.getCasefile().getBytes(StandardCharsets.UTF_8));
        schemas.validate("CasefileSnapshot", draft.getCasefileSnapshot().getBytes(StandardCharsets.UTF_8));
        try {
            JsonNode saved = json.readTree(draft.getCasefile());
            casefiles.validate(draft.getBusinessUnitId(), CasefileType.fromValue(draft.getCasefileType()), saved);
            return saved;
        } catch (JacksonException exception) {
            throw new IllegalStateException("Invalid saved publication data");
        }
    }

    private static boolean blank(String value) {
        return value == null || value.isBlank();
    }
}
