package uk.gov.hmcts.opal.mapper;

import org.mapstruct.InjectionStrategy;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.MappingConstants;
import org.mapstruct.ReportingPolicy;
import org.mapstruct.ValueMapping;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;
import uk.gov.hmcts.opal.entity.DraftCasefileStatus;
import uk.gov.hmcts.opal.generated.model.DraftCasefileAddResponse;

@Mapper(componentModel = "spring", injectionStrategy = InjectionStrategy.CONSTRUCTOR,
    unmappedTargetPolicy = ReportingPolicy.ERROR,
    uses = {DraftCasefileJsonMapper.class, DraftCasefileValueMapper.class})
public interface DraftCasefileAddResponseMapper {

    @Mapping(target = "casefileSnapshot", source = "casefileSnapshot", qualifiedByName = "storedSnapshot")
    @Mapping(target = "timelineData", source = "timelineData", qualifiedByName = "storedSubmissionTimeline")
    @Mapping(target = "casefileType", source = "casefileType", qualifiedByName = "casefileType")
    DraftCasefileAddResponse toResponse(DraftCasefileEntity entity);

    @ValueMapping(source = MappingConstants.ANY_REMAINING, target = MappingConstants.THROW_EXCEPTION)
    DraftCasefileAddResponse.CasefileStatusEnum submissionStatus(DraftCasefileStatus status);
}
