package uk.gov.hmcts.opal.dto;

public record VersionedResponse<T>(T response, long version) { }
