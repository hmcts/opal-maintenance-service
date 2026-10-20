package uk.gov.hmcts.opal.steps;

import java.util.Map;

record RmUserStateTestUsers(TestUser granted, TestUser denied, short businessUnitId) {
    private static final String GRANTED_EMAIL = "RM_USER_STATE_GRANTED_USER_EMAIL";
    private static final String GRANTED_ID = "RM_USER_STATE_GRANTED_USER_ID";
    private static final String DENIED_EMAIL = "RM_USER_STATE_DENIED_USER_EMAIL";
    private static final String DENIED_ID = "RM_USER_STATE_DENIED_USER_ID";
    private static final String BU_ID = "RM_USER_STATE_BUSINESS_UNIT_ID";

    static RmUserStateTestUsers fromEnvironment(Map<String, String> environment) {
        String grantedEmail = email(environment, GRANTED_EMAIL);
        long grantedId = positiveLong(environment, GRANTED_ID);
        String deniedEmail = email(environment, DENIED_EMAIL);
        long deniedId = positiveLong(environment, DENIED_ID);
        short buId = positiveShort(environment, BU_ID);
        if (grantedEmail.equalsIgnoreCase(deniedEmail)) {
            throw invalid(DENIED_EMAIL);
        }
        if (grantedId == deniedId) {
            throw invalid(DENIED_ID);
        }
        return new RmUserStateTestUsers(new TestUser(grantedEmail, grantedId),
            new TestUser(deniedEmail, deniedId), buId);
    }

    private static String email(Map<String, String> environment, String setting) {
        String value = environment.get(setting);
        if (value == null || value.isBlank()) {
            throw invalid(setting);
        }
        return value;
    }

    private static long positiveLong(Map<String, String> environment, String setting) {
        String value = environment.get(setting);
        try {
            long parsed = Long.parseLong(value);
            if (parsed > 0) {
                return parsed;
            }
        } catch (NumberFormatException ignored) {
            // Reject with the setting name only; the supplied value may identify an account.
        }
        throw invalid(setting);
    }

    private static short positiveShort(Map<String, String> environment, String setting) {
        String value = environment.get(setting);
        try {
            short parsed = Short.parseShort(value);
            if (parsed > 0) {
                return parsed;
            }
        } catch (NumberFormatException ignored) {
            // Reject with the setting name only.
        }
        throw invalid(setting);
    }

    private static IllegalStateException invalid(String setting) {
        return new IllegalStateException("Missing or invalid " + setting);
    }

    record TestUser(String email, long userId) { }
}
