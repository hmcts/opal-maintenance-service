package uk.gov.hmcts.opal.validator;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.NullAndEmptySource;
import org.junit.jupiter.params.provider.ValueSource;
import uk.gov.hmcts.opal.common.exception.OpalApiException;
import uk.gov.hmcts.opal.exception.RequestValidationError;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.catchThrowableOfType;

class IfMatchValidatorTest {

    private final IfMatchValidator validator = new IfMatchValidator();

    @Test
    void parsesQuotedNonNegativeVersionsWithinLongRange() {
        assertThat(validator.parseIfMatch("\"0\"")).isZero();
        assertThat(validator.parseIfMatch("\"001\"")).isEqualTo(1L);
        assertThat(validator.parseIfMatch("\"9223372036854775807\"")).isEqualTo(Long.MAX_VALUE);
    }

    @ParameterizedTest
    @NullAndEmptySource
    @ValueSource(strings = {"1", "\"-1\"", "W/\"1\"", "*", "\"1\",\"2\"", "\"x\"", "\"1",
        "\"9223372036854775808\"", " \"1\"", "\"1\" ", "SYNTHETIC_PRIVATE_VALUE", "\"\""})
    void rejectsInvalidVersionsWithoutDisclosingHeader(String value) {
        OpalApiException exception = catchThrowableOfType(OpalApiException.class,
            () -> validator.parseIfMatch(value));
        assertThat(exception).isNotNull();
        assertThat(exception.getError()).isEqualTo(RequestValidationError.INVALID_REQUEST);
        assertThat(exception.getDetail()).isEqualTo("If-Match must contain one quoted non-negative version");
        assertThat(exception.getCause()).isNull();
    }
}
