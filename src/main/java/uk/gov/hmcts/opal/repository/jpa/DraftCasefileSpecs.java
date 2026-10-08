package uk.gov.hmcts.opal.repository.jpa;

import jakarta.persistence.criteria.Predicate;
import org.springframework.data.jpa.domain.Specification;
import uk.gov.hmcts.opal.dto.DraftCasefileFilter;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity_;

import java.util.ArrayList;
import java.util.List;

public final class DraftCasefileSpecs {

    private DraftCasefileSpecs() {
    }

    public static Specification<DraftCasefileEntity> matches(DraftCasefileFilter filter) {
        return (root, query, builder) -> {
            List<Predicate> predicates = new ArrayList<>();
            predicates.add(builder.equal(root.get(DraftCasefileEntity_.businessUnitId), filter.businessUnitId()));
            if (filter.submittedBy() != null) {
                predicates.add(builder.equal(root.get(DraftCasefileEntity_.submittedBy), filter.submittedBy()));
            }
            if (filter.notSubmittedBy() != null) {
                predicates.add(builder.notEqual(root.get(DraftCasefileEntity_.submittedBy), filter.notSubmittedBy()));
            }
            if (!filter.statuses().isEmpty()) {
                predicates.add(root.get(DraftCasefileEntity_.casefileStatus).in(filter.statuses()));
            }
            if (filter.fromInclusive() != null) {
                predicates.add(builder.greaterThanOrEqualTo(root.get(DraftCasefileEntity_.casefileStatusDate),
                    filter.fromInclusive()));
            }
            if (filter.toExclusive() != null) {
                predicates.add(builder.lessThan(root.get(DraftCasefileEntity_.casefileStatusDate),
                    filter.toExclusive()));
            }
            return builder.and(predicates.toArray(Predicate[]::new));
        };
    }
}
