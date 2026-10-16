package uk.gov.hmcts.opal.controllers;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import uk.gov.hmcts.opal.dto.TestingSupportDraftCasefileMatches;
import uk.gov.hmcts.opal.dto.TestingSupportDraftCasefileMetadata;
import uk.gov.hmcts.opal.entity.DraftCasefileStatus;
import uk.gov.hmcts.opal.service.TestingSupportDraftCasefileService;

import java.util.List;

@ExtendWith(MockitoExtension.class)
class TestingSupportControllerTest {

    private final TestingSupportDraftCasefileService service = mock(TestingSupportDraftCasefileService.class);
    private final TestingSupportController controller = new TestingSupportController(service);

    @Test
    void returnsOkPingResponse() {
        assertThat(controller.ping().getBody())
            .isEqualTo(new TestingSupportController.PingResponse("ok"));
    }

    @Test
    void delegatesInspect() {
        TestingSupportDraftCasefileMetadata metadata = new TestingSupportDraftCasefileMetadata(
            123L, (short) 44, "L044JG", null, DraftCasefileStatus.SUBMITTED, null, 0L, true, 1,
            List.of("Submitted"));
        when(service.inspect(123L)).thenReturn(metadata);

        assertThat(controller.inspect(123L).getBody()).isEqualTo(metadata);
    }

    @Test
    void delegatesFindByMarker() {
        String marker = "PO10287-550e8400-e29b-41d4-a716-446655440000";
        TestingSupportDraftCasefileMatches matches = new TestingSupportDraftCasefileMatches(1, List.of(123L));
        when(service.findByMarker(marker)).thenReturn(matches);

        assertThat(controller.findByMarker(marker).getBody()).isEqualTo(matches);
    }

    @Test
    void deletesWithNoContent() {
        assertThat(controller.delete(123L).getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
        verify(service).delete(123L);
    }
}
