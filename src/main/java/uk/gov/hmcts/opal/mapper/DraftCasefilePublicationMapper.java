package uk.gov.hmcts.opal.mapper;

import org.springframework.stereotype.Component;
import tools.jackson.core.JacksonException;
import tools.jackson.core.StreamReadFeature;
import tools.jackson.databind.DeserializationFeature;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;
import tools.jackson.databind.node.ObjectNode;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;
import uk.gov.hmcts.opal.entity.DraftCasefileStatus;
import uk.gov.hmcts.opal.repository.extensions.DraftCasefilePublicationRepository.PublicationResult;

import java.util.HashMap;
import java.util.Map;

@Component
public class DraftCasefilePublicationMapper {
    private static final JsonMapper JSON = JsonMapper.builder()
        .enable(StreamReadFeature.STRICT_DUPLICATE_DETECTION)
        .enable(DeserializationFeature.FAIL_ON_TRAILING_TOKENS).build();

    public String mergePublishedAccounts(String originalSnapshotJson, JsonNode savedCasefile,
                                         PublicationResult result) {
        validatePendingSnapshot(originalSnapshotJson, savedCasefile);
        final ObjectNode snapshot = object(parse(originalSnapshotJson));
        if (result == null) {
            throw invalid();
        }
        JsonNode output = object(parse(result.publishedAccountsJson()));
        JsonNode respondent = output.path("respondent_account");
        requireIdentity(respondent);
        if (!Long.valueOf(respondent.get("account_id").longValue()).equals(result.respondentAccountId())
            || !respondent.get("account_number").asString().equals(result.accountNumber())) {
            throw invalid();
        }
        copyIdentity(snapshot.path("respondent_account"), respondent);
        copyIdentity(snapshot.path("applicant_account"), output.path("applicant_account"));
        Map<Integer, JsonNode> targets = minors(snapshot.get("minor_creditor_accounts"));
        Map<Integer, JsonNode> sources = minors(output.get("minor_creditor_accounts"));
        if (!targets.keySet().equals(sources.keySet())) {
            throw invalid();
        }
        targets.forEach((sequence, target) -> copyIdentity(target, sources.get(sequence)));
        return snapshot.toString();
    }

    public void validatePendingSnapshot(String snapshotJson, JsonNode savedCasefile) {
        JsonNode snapshot = object(parse(snapshotJson));
        requireUnpublished(snapshot.path("respondent_account"));
        requireUnpublished(snapshot.path("applicant_account"));
        Map<Integer, JsonNode> accounts = minors(snapshot.get("minor_creditor_accounts"));
        JsonNode savedMinors = savedCasefile.get("minor_creditors");
        Map<Integer, JsonNode> source = savedMinors == null ? Map.of() : minors(savedMinors);
        if (!accounts.keySet().equals(source.keySet())) {
            throw invalid();
        }
        accounts.values().forEach(DraftCasefilePublicationMapper::requireUnpublished);
    }

    /** Reject evidence of an existing graph before treating a delivery as pending or a duplicate. */
    public void validatePublicationState(DraftCasefileEntity draft) {
        boolean published = draft.getCasefileStatus() == DraftCasefileStatus.PUBLISHED;
        if (!published && (draft.getAccountId() != null || draft.getAccountNumber() != null)) {
            throw invalid();
        }
        final JsonNode snapshot;
        try {
            snapshot = object(parse(draft.getCasefileSnapshot()));
        } catch (IllegalStateException exception) {
            if (draft.getCasefileStatus() == DraftCasefileStatus.PUBLISHING_PENDING) {
                return; // Malformed saved data is handled as a business-processing failure after capturing the attempt.
            }
            throw exception;
        }
        if (published) {
            JsonNode respondent = snapshot.path("respondent_account");
            requireIdentity(respondent);
            if (!Long.valueOf(respondent.get("account_id").longValue()).equals(draft.getAccountId())
                || !respondent.get("account_number").asString().equals(draft.getAccountNumber())) {
                throw invalid();
            }
            requireIdentity(snapshot.path("applicant_account"));
            minors(snapshot.get("minor_creditor_accounts")).values()
                .forEach(DraftCasefilePublicationMapper::requireIdentity);
        } else if (hasIdentity(snapshot.path("respondent_account"))
            || hasIdentity(snapshot.path("applicant_account"))) {
            throw invalid();
        } else {
            for (JsonNode minor : snapshot.path("minor_creditor_accounts")) {
                if (hasIdentity(minor)) {
                    throw invalid();
                }
            }
        }
    }

    private static boolean hasIdentity(JsonNode account) {
        return account.hasNonNull("account_id") || account.hasNonNull("account_number");
    }

    private static void requireUnpublished(JsonNode account) {
        if (!account.isObject() || hasIdentity(account)) {
            throw invalid();
        }
    }

    private static void copyIdentity(JsonNode target, JsonNode source) {
        requireIdentity(source);
        object(target).put("account_id", source.get("account_id").longValue());
        object(target).put("account_number", source.get("account_number").asString());
    }

    private static void requireIdentity(JsonNode account) {
        JsonNode id = account.path("account_id");
        JsonNode number = account.path("account_number");
        if (!id.isIntegralNumber() || !id.canConvertToLong() || id.longValue() <= 0
            || !number.isString() || number.asString().isBlank()) {
            throw invalid();
        }
    }

    private static Map<Integer, JsonNode> minors(JsonNode array) {
        if (array == null || !array.isArray()) {
            throw invalid();
        }
        Map<Integer, JsonNode> result = new HashMap<>();
        for (JsonNode minor : array) {
            JsonNode sequence = minor.path("creditor_sequence");
            if (!sequence.isIntegralNumber() || !sequence.canConvertToInt() || sequence.intValue() <= 0
                || result.putIfAbsent(sequence.intValue(), minor) != null) {
                throw invalid();
            }
        }
        return result;
    }

    private static JsonNode parse(String json) {
        if (json == null) {
            throw invalid();
        }
        try {
            return JSON.readTree(json);
        } catch (JacksonException exception) {
            throw invalid();
        }
    }

    private static ObjectNode object(JsonNode value) {
        if (!(value instanceof ObjectNode object)) {
            throw invalid();
        }
        return object;
    }

    private static IllegalStateException invalid() {
        return new IllegalStateException("Invalid publication identity contract");
    }
}
