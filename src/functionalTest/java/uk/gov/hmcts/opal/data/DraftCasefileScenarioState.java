package uk.gov.hmcts.opal.data;

import io.restassured.response.Response;

import java.util.UUID;

public final class DraftCasefileScenarioState {

    private String marker;
    private Response latestResponse;
    private Long createdId;
    private String cleanupToken;

    public void reset() {
        marker = "PO10287-" + UUID.randomUUID();
        latestResponse = null;
        createdId = null;
        cleanupToken = null;
    }

    public void clearAfterCleanup() {
        latestResponse = null;
        createdId = null;
        cleanupToken = null;
    }

    public String marker() {
        if (marker == null) {
            throw new IllegalStateException("Draft Casefile scenario state has not been reset");
        }
        return marker;
    }

    public Response latestResponse() {
        return latestResponse;
    }

    public void latestResponse(Response response) {
        latestResponse = response;
    }

    public Long createdId() {
        return createdId;
    }

    public void createdId(long id) {
        createdId = id;
    }

    public String cleanupToken() {
        return cleanupToken;
    }

    public void cleanupToken(String token) {
        cleanupToken = token;
    }
}
