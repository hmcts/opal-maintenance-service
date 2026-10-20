package uk.gov.hmcts.opal.steps;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.HashMap;
import java.util.Map;
import org.junit.jupiter.api.Test;

class RmUserStateTestUsersTest {
    private static final String GRANTED_EMAIL = "RM_USER_STATE_GRANTED_USER_EMAIL";
    private static final String GRANTED_ID = "RM_USER_STATE_GRANTED_USER_ID";
    private static final String DENIED_EMAIL = "RM_USER_STATE_DENIED_USER_EMAIL";
    private static final String DENIED_ID = "RM_USER_STATE_DENIED_USER_ID";
    private static final String BU_ID = "RM_USER_STATE_BUSINESS_UNIT_ID";

    private Map<String, String> valid() {
        return new HashMap<>(Map.of(GRANTED_EMAIL, "one@example.invalid", GRANTED_ID, "101",
            DENIED_EMAIL, "two@example.invalid", DENIED_ID, "102", BU_ID, "44"));
    }

    @Test
    void acceptsSeparateSyntheticUsers() {
        var users = RmUserStateTestUsers.fromEnvironment(valid());
        assertEquals(101, users.granted().userId());
        assertEquals(102, users.denied().userId());
        assertEquals(44, users.businessUnitId());
    }

    @Test
    void rejectsEveryMissingSettingWithoutItsValue() {
        for (String key : valid().keySet()) {
            var values = valid();
            values.remove(key);
            assertInvalid(values, key);
        }
    }

    @Test
    void rejectsEqualEmailsIgnoringCaseAndEqualIds() {
        var values = valid();
        values.put(DENIED_EMAIL, "ONE@example.invalid");
        assertInvalid(values, DENIED_EMAIL);
        values = valid();
        values.put(DENIED_ID, "101");
        assertInvalid(values, DENIED_ID);
    }

    @Test
    void rejectsBlankEmailsAndInvalidNumericBoundaries() {
        for (String email : new String[]{"", " "}) {
            var values = valid();
            values.put(GRANTED_EMAIL, email);
            assertInvalid(values, GRANTED_EMAIL);
        }
        for (String value : new String[]{"bad-value", "0", "-1", "9223372036854775808"}) {
            var values = valid();
            values.put(GRANTED_ID, value);
            assertInvalid(values, GRANTED_ID);
        }
        for (String value : new String[]{"bad-value", "0", "-1", "32768"}) {
            var values = valid();
            values.put(BU_ID, value);
            assertInvalid(values, BU_ID);
        }
    }

    private void assertInvalid(Map<String, String> values, String setting) {
        var error = assertThrows(IllegalStateException.class, () -> RmUserStateTestUsers.fromEnvironment(values));
        assertTrue(error.getMessage().contains(setting));
        for (String value : values.values()) {
            if (!value.isBlank()) {
                assertFalse(error.getMessage().contains(value));
            }
        }
    }
}
