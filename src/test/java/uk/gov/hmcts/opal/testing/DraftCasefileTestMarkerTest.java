package uk.gov.hmcts.opal.testing;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.NullAndEmptySource;
import org.junit.jupiter.params.provider.ValueSource;
import uk.gov.hmcts.opal.common.exception.OpalApiException;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class DraftCasefileTestMarkerTest {

    private final DraftCasefileTestMarker subject = new DraftCasefileTestMarker();

    @ParameterizedTest
    @ValueSource(strings = {
        "PO10287-550e8400-e29b-41d4-a716-446655440000",
        "PO10287-00000000-0000-4000-8000-000000000000"
    })
    void acceptsLowercaseUuidV4Markers(String marker) {
        assertThat(subject.isValid(marker)).isTrue();
    }

    @ParameterizedTest
    @NullAndEmptySource
    @ValueSource(strings = {
        "PO10287-550E8400-E29B-41D4-A716-446655440000",
        "PO10287-550e8400-e29b-11d4-a716-446655440000",
        "PO10287-%",
        "PO10287-550e8400-e29b-41d4-a716-446655440000-extra"
    })
    void rejectsAnythingOutsideTheExactMarkerShape(String marker) {
        assertThat(subject.isValid(marker)).isFalse();
        assertThatThrownBy(() -> subject.requireValid(marker)).isInstanceOf(OpalApiException.class)
            .hasMessageContaining("Invalid PO-10287 testing marker");
    }

    @Test
    void acceptsValidMarkerForRequiredValidation() {
        subject.requireValid("PO10287-550e8400-e29b-41d4-a716-446655440000");
    }
}
