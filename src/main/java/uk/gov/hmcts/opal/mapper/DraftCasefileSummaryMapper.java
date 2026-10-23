package uk.gov.hmcts.opal.mapper;

import org.mapstruct.InjectionStrategy;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.ReportingPolicy;
import uk.gov.hmcts.opal.generated.model.DraftCasefileSummary;
import uk.gov.hmcts.opal.repository.DraftCasefileSummaryProjection;

@Mapper(componentModel = "spring", injectionStrategy = InjectionStrategy.CONSTRUCTOR,
    unmappedTargetPolicy = ReportingPolicy.ERROR,
    uses = {DraftCasefileJsonMapper.class, DraftCasefileValueMapper.class})
public interface DraftCasefileSummaryMapper {
    @Mapping(target = "casefileSnapshot", source = "casefileSnapshot", qualifiedByName = "storedSnapshot")
    @Mapping(target = "casefileType", source = "casefileType", qualifiedByName = "casefileType")
    @Mapping(target = "casefileStatusName", source = "casefileStatus.displayName")
    @Mapping(target = "validatedDate", source = "validatedDate", qualifiedByName = "nullableUtc")
    DraftCasefileSummary toSummary(DraftCasefileSummaryProjection projection);

}
