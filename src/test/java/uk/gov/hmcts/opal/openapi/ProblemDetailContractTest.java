package uk.gov.hmcts.opal.openapi;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.UUID;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import uk.gov.hmcts.opal.generated.model.ProblemDetail;

@DisplayName("PO-10251 shared ProblemDetail OpenAPI contract")
class ProblemDetailContractTest {

    @Test
    @DisplayName("PO-10251 exposes OPAL correlation fields at the top level")
    void exposesTopLevelOpalCorrelationFields() {
        UUID operationId = UUID.randomUUID();

        ProblemDetail problem = ProblemDetail.builder()
            .title("Not Acceptable")
            .status(406)
            .detail("Invalid parameter value format")
            .operationId(operationId)
            .retriable(false)
            .build();

        assertThat(problem.getOperationId()).isEqualTo(operationId);
        assertThat(problem.getRetriable()).isFalse();
    }
}
