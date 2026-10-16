package uk.gov.hmcts.opal.data;

public enum InvalidDraftReference {
    UNKNOWN_APPLICATION,
    INACTIVE_COUNTRY,
    HISTORICAL_COUNTRY;

    public static InvalidDraftReference fromFeatureValue(String value) {
        return switch (value) {
            case "unknown application" -> UNKNOWN_APPLICATION;
            case "inactive country" -> INACTIVE_COUNTRY;
            case "historical country" -> HISTORICAL_COUNTRY;
            default -> throw new IllegalArgumentException("Unknown Draft Casefile reference variant: " + value);
        };
    }
}
