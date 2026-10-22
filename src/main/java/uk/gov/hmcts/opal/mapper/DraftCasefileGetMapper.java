package uk.gov.hmcts.opal.mapper;

import org.mapstruct.InjectionStrategy;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.Named;
import org.mapstruct.ReportingPolicy;
import org.openapitools.jackson.nullable.JsonNullable;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;
import uk.gov.hmcts.opal.generated.model.CasefileType;
import uk.gov.hmcts.opal.generated.model.DraftCasefileGetResponse;

import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;

@Mapper(componentModel = "spring", injectionStrategy = InjectionStrategy.CONSTRUCTOR,
    unmappedTargetPolicy = ReportingPolicy.ERROR, uses = DraftCasefileJsonMapper.class)
public interface DraftCasefileGetMapper {

    @Mapping(target = "casefile", source = "casefile", qualifiedByName = "storedCasefile")
    @Mapping(target = "casefileSnapshot", source = "casefileSnapshot", qualifiedByName = "storedSnapshot")
    @Mapping(target = "timelineData", source = "timelineData", qualifiedByName = "storedTimeline")
    @Mapping(target = "casefileType", source = "casefileType", qualifiedByName = "casefileType")
    @Mapping(target = "casefileStatusName", expression = "java(entity.getCasefileStatus().getDisplayName())")
    @Mapping(target = "validatedDate", source = "validatedDate", qualifiedByName = "nullableUtc")
    DraftCasefileGetResponse toResponse(DraftCasefileEntity entity);

    @Named("casefileType")
    default CasefileType casefileType(String value) {
        return CasefileType.fromValue(value);
    }

    default OffsetDateTime utc(LocalDateTime value) {
        return value == null ? null : value.atOffset(ZoneOffset.UTC);
    }

    @Named("nullableUtc")
    default JsonNullable<OffsetDateTime> nullableUtc(LocalDateTime value) {
        return JsonNullable.of(utc(value));
    }

    default <T> JsonNullable<T> mapToJsonNullable(T value) {
        return JsonNullable.of(value);
    }
}
