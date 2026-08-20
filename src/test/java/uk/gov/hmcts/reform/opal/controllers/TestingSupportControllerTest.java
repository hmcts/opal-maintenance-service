package uk.gov.hmcts.reform.opal.controllers;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class TestingSupportControllerTest {


    @Test
    void returnsOkPingResponse() {
        assertThat(new TestingSupportController().ping().getBody())
            .isEqualTo(new TestingSupportController.PingResponse("ok"));
    }
}
