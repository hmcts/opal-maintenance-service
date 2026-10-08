package uk.gov.hmcts.opal.validator;

import org.junit.jupiter.api.Test;
import uk.gov.hmcts.opal.common.exception.OpalApiException;
import uk.gov.hmcts.opal.entity.DraftCasefileStatus;
import uk.gov.hmcts.opal.exception.RequestValidationError;
import uk.gov.hmcts.opal.generated.model.DraftCasefileLifecycleStatus;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class DraftCasefileQueryValidatorTest {
    private final DraftCasefileQueryValidator validator = new DraftCasefileQueryValidator();

    @Test
    void usesWholeUtcDaysAndDoesNotAddAnImplicitRange() {
        var bounded = validator.validate((short) 44, null, null,
            List.of(DraftCasefileLifecycleStatus.REJECTED), LocalDate.of(2026, 7, 1),
            LocalDate.of(2026, 7, 1), null);
        assertThat(bounded.fromInclusive()).isEqualTo(LocalDateTime.parse("2026-07-01T00:00:00"));
        assertThat(bounded.toExclusive()).isEqualTo(LocalDateTime.parse("2026-07-02T00:00:00"));
        var unbounded = validator.validate((short) 44, null, null, null, null, null, "counts");
        assertThat(unbounded.fromInclusive()).isNull();
        assertThat(unbounded.toExclusive()).isNull();
        assertThat(unbounded.statuses()).isEmpty();
    }

    @Test
    void normalisesStatusesAndAllowsIndependentBoundsAndContradictorySubmitters() {
        var from = validator.validate((short) 44, "BUU-1", "BUU-1",
            List.of(DraftCasefileLifecycleStatus.REJECTED, DraftCasefileLifecycleStatus.REJECTED),
            LocalDate.of(2026, 7, 1), null, null);
        assertThat(from.statuses()).containsExactly(DraftCasefileStatus.REJECTED);
        assertThat(from.toExclusive()).isNull();
        var to = validator.validate((short) 44, null, null, null, null, LocalDate.of(2026, 7, 1), null);
        assertThat(to.fromInclusive()).isNull();
        assertThat(to.toExclusive()).isEqualTo(LocalDateTime.parse("2026-07-02T00:00:00"));
    }

    @Test
    void rejectsInvalidFiltersWithoutEchoingValues() {
        for (Short id : Arrays.asList(null, (short) 0, (short) -1)) {
            assertInvalid(() -> validator.validate(id, null, null, null, null, null, null));
        }
        for (String submitter : List.of("", " ", "SYNTHETIC_PRIVATE_QUERY")) {
            assertInvalid(() -> validator.validate((short) 44, submitter, null, null, null, null, null));
            assertInvalid(() -> validator.validate((short) 44, null, submitter, null, null, null, null));
        }
        for (String restrict : List.of("", "SYNTHETIC_PRIVATE_QUERY")) {
            assertInvalid(() -> validator.validate((short) 44, null, null, null, null, null, restrict));
        }
        assertInvalid(() -> validator.validate((short) 44, null, null, List.of(), null, null, null));
        assertInvalid(() -> validator.validate((short) 44, null, null,
            Arrays.asList((DraftCasefileLifecycleStatus) null), null, null, null));
        assertInvalid(() -> validator.validate((short) 44, null, null, null,
            LocalDate.of(2026, 7, 2), LocalDate.of(2026, 7, 1), null));
        assertInvalid(() -> validator.validate((short) 44, null, null, null, null, LocalDate.MAX, null));
    }

    private static void assertInvalid(org.assertj.core.api.ThrowableAssert.ThrowingCallable operation) {
        assertThatThrownBy(operation).isInstanceOf(OpalApiException.class)
            .hasMessageNotContaining("SYNTHETIC_PRIVATE_QUERY")
            .satisfies(failure -> assertThat(((OpalApiException) failure).getError())
                .isEqualTo(RequestValidationError.INVALID_REQUEST));
    }
}
