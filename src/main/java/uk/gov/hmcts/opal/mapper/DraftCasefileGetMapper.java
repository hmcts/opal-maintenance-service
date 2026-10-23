package uk.gov.hmcts.opal.mapper;

import org.mapstruct.InjectionStrategy;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.ReportingPolicy;
import org.openapitools.jackson.nullable.JsonNullable;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;
import uk.gov.hmcts.opal.generated.model.DraftCasefileGetResponse;

@Mapper(componentModel = "spring", injectionStrategy = InjectionStrategy.CONSTRUCTOR,
    unmappedTargetPolicy = ReportingPolicy.ERROR,
    uses = {DraftCasefileJsonMapper.class, DraftCasefileValueMapper.class})
public interface DraftCasefileGetMapper {

    @Mapping(target = "casefile", source = "casefile", qualifiedByName = "storedCasefile")
    @Mapping(target = "casefileSnapshot", source = "casefileSnapshot", qualifiedByName = "storedSnapshot")
    @Mapping(target = "timelineData", source = "timelineData", qualifiedByName = "storedTimeline")
    @Mapping(target = "casefileType", source = "casefileType", qualifiedByName = "casefileType")
    @Mapping(target = "casefileStatusName", source = "casefileStatus.displayName")
    @Mapping(target = "validatedDate", source = "validatedDate", qualifiedByName = "nullableUtc")
    DraftCasefileGetResponse toResponse(DraftCasefileEntity entity);

    default <T> JsonNullable<T> mapToJsonNullable(T value) {
        return JsonNullable.of(value);
    }
}
