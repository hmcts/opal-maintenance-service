package uk.gov.hmcts.opal.testing;

import org.junit.jupiter.api.Test;
import uk.gov.hmcts.opal.common.exception.OpalApiException;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.assertj.core.api.Assertions.catchThrowableOfType;

class DraftCasefileTestingFailureTest {

    @Test
    void returnsNoneWhenHeaderIsAbsent() {
        assertThat(new DraftCasefileTestingFailure(false).resolve(null))
            .isEqualTo(DraftCasefileFailureMode.NONE);
    }

    @Test
    void rejectsHeaderWhenTestingSupportIsDisabled() {
        OpalApiException failure = catchThrowableOfType(OpalApiException.class,
            () -> new DraftCasefileTestingFailure(false).resolve("after-save"));
        assertThat(failure.getDetail()).isEqualTo("Testing failure injection is disabled");
    }

    @Test
    void acceptsOnlyAfterSaveWhenEnabled() {
        DraftCasefileTestingFailure failure = new DraftCasefileTestingFailure(true);
        assertThat(failure.resolve("after-save")).isEqualTo(DraftCasefileFailureMode.AFTER_SAVE);
        assertThatThrownBy(() -> failure.resolve("before-save")).isInstanceOf(OpalApiException.class);
    }

    @Test
    void raisesControlledFailureOnlyForAfterSave() {
        DraftCasefileTestingFailure failure = new DraftCasefileTestingFailure(true);
        assertThatCode(() -> failure.afterSave(DraftCasefileFailureMode.NONE)).doesNotThrowAnyException();
        assertThatThrownBy(() -> failure.afterSave(DraftCasefileFailureMode.AFTER_SAVE))
            .isInstanceOf(DraftCasefileTestingFailureException.class);
    }
}
