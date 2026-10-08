package uk.gov.hmcts.opal.mapper;

import org.mapstruct.Named;
import org.openapitools.jackson.nullable.JsonNullable;
import org.springframework.stereotype.Component;
import uk.gov.hmcts.opal.generated.model.CasefileType;

import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;

@Component
public class DraftCasefileValueMapper {

    @Named("casefileType")
    public CasefileType casefileType(String value) {
        return CasefileType.fromValue(value);
    }

    public OffsetDateTime utc(LocalDateTime value) {
        return value == null ? null : value.atOffset(ZoneOffset.UTC);
    }

    @Named("nullableUtc")
    public JsonNullable<OffsetDateTime> nullableUtc(LocalDateTime value) {
        return JsonNullable.of(utc(value));
    }
}
