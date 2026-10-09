package uk.gov.hmcts.opal.validator;

import org.springframework.stereotype.Component;
import uk.gov.hmcts.opal.common.exception.OpalApiException;
import uk.gov.hmcts.opal.dto.DraftCasefileFilter;
import uk.gov.hmcts.opal.entity.DraftCasefileStatus;
import uk.gov.hmcts.opal.exception.RequestValidationError;
import uk.gov.hmcts.opal.generated.model.DraftCasefileLifecycleStatus;

import java.time.DateTimeException;
import java.time.LocalDate;
import java.util.List;
import java.util.Objects;

@Component
public class DraftCasefileQueryValidator {
    public DraftCasefileFilter validate(Short businessUnitId, String submittedBy, String notSubmittedBy,
                                       List<DraftCasefileLifecycleStatus> statuses, LocalDate fromDate,
                                       LocalDate toDate, String restrict) {
        if (businessUnitId == null || businessUnitId <= 0) {
            throw invalid("Business Unit must be a positive identifier");
        }
        validateSubmitter(submittedBy);
        validateSubmitter(notSubmittedBy);
        if (restrict != null && !"counts".equals(restrict)) {
            throw invalid("Unsupported query restriction");
        }
        if (statuses != null && (statuses.isEmpty() || statuses.stream().anyMatch(Objects::isNull))) {
            throw invalid("At least one status is required when the status filter is supplied");
        }
        if (fromDate != null && toDate != null && fromDate.isAfter(toDate)) {
            throw invalid("From date must not be after to date");
        }
        List<DraftCasefileStatus> selected = statuses == null ? List.of() : statuses.stream()
            .map(value -> DraftCasefileStatus.valueOf(value.getValue())).distinct().toList();
        try {
            return new DraftCasefileFilter(businessUnitId, submittedBy, notSubmittedBy, selected,
                fromDate == null ? null : fromDate.atStartOfDay(),
                toDate == null ? null : toDate.plusDays(1).atStartOfDay());
        } catch (DateTimeException exception) {
            throw invalid("Date range cannot be represented");
        }
    }

    private static void validateSubmitter(String value) {
        if (value != null && (value.isBlank() || value.length() > 20)) {
            throw invalid("Submitter must be a nonblank Business Unit User identifier of at most 20 characters");
        }
    }

    private static OpalApiException invalid(String detail) {
        return new OpalApiException(RequestValidationError.INVALID_REQUEST, detail);
    }
}
