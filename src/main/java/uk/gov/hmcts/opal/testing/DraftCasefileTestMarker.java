package uk.gov.hmcts.opal.testing;

import org.springframework.stereotype.Component;
import uk.gov.hmcts.opal.common.exception.OpalApiException;
import uk.gov.hmcts.opal.exception.DraftCasefileError;

import java.util.regex.Pattern;

@Component
public class DraftCasefileTestMarker {

    private static final Pattern MARKER = Pattern.compile(
        "PO10287-[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}"
    );

    public boolean isValid(String value) {
        return value != null && MARKER.matcher(value).matches();
    }

    public void requireValid(String value) {
        if (!isValid(value)) {
            throw new OpalApiException(DraftCasefileError.INVALID_REQUEST, "Invalid PO-10287 testing marker");
        }
    }
}
