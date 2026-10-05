package uk.gov.hmcts.opal.mapper;

import org.mapstruct.InjectionStrategy;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.Named;
import org.mapstruct.ReportingPolicy;
import org.openapitools.jackson.nullable.JsonNullable;
import uk.gov.hmcts.opal.entity.DraftCasefileStatus;
import uk.gov.hmcts.opal.generated.model.CasefileType;
import uk.gov.hmcts.opal.generated.model.DraftCasefileLifecycleStatus;
import uk.gov.hmcts.opal.generated.model.DraftCasefileSummary;
import uk.gov.hmcts.opal.repository.DraftCasefileSummaryProjection;

import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;

@Mapper(componentModel = "spring", injectionStrategy = InjectionStrategy.CONSTRUCTOR,
    unmappedTargetPolicy = ReportingPolicy.ERROR, uses = DraftCasefileJsonMapper.class,
    imports = {DraftCasefileStatus.class, DraftCasefileLifecycleStatus.class})
public interface DraftCasefileSummaryMapper {
    @Mapping(target = "casefileSnapshot", source = "casefileSnapshot", qualifiedByName = "storedSnapshot")
    @Mapping(target = "casefileType", source = "casefileType", qualifiedByName = "summaryCasefileType")
    @Mapping(target = "casefileStatus",
        expression = "java(DraftCasefileLifecycleStatus.fromValue(projection.getCasefileStatus()))")
    @Mapping(target = "casefileStatusName",
        expression = "java(DraftCasefileStatus.valueOf(projection.getCasefileStatus()).getDisplayName())")
    @Mapping(target = "validatedDate", source = "validatedDate", qualifiedByName = "summaryNullableUtc")
    DraftCasefileSummary toSummary(DraftCasefileSummaryProjection projection);

    @Named("summaryCasefileType")
    default CasefileType casefileType(String value) {
        return CasefileType.fromValue(value);
    }

    default OffsetDateTime utc(LocalDateTime value) {
        return value == null ? null : value.atOffset(ZoneOffset.UTC);
    }

    @Named("summaryNullableUtc")
    default JsonNullable<OffsetDateTime> nullableUtc(LocalDateTime value) {
        return JsonNullable.of(utc(value));
    }
}
