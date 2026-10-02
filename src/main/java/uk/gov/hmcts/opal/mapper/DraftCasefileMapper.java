package uk.gov.hmcts.opal.mapper;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import org.openapitools.jackson.nullable.JsonNullable;
import org.springframework.stereotype.Component;
import tools.jackson.databind.JsonNode;
import uk.gov.hmcts.opal.authorisation.MaintenanceUser;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;
import uk.gov.hmcts.opal.entity.DraftCasefileStatus;
import uk.gov.hmcts.opal.generated.model.CasefileSnapshot;
import uk.gov.hmcts.opal.generated.model.CasefileSnapshotApplicantAccount;
import uk.gov.hmcts.opal.generated.model.CasefileSnapshotMinorCreditorAccount;
import uk.gov.hmcts.opal.generated.model.CasefileSnapshotRespondentAccount;
import uk.gov.hmcts.opal.generated.model.CasefileType;
import uk.gov.hmcts.opal.generated.model.DraftCasefileAddRequest;
import uk.gov.hmcts.opal.generated.model.DraftCasefileAddResponse;
import uk.gov.hmcts.opal.generated.model.DraftCasefileSubmissionTimelineEntry;

import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

@Component
@RequiredArgsConstructor
public class DraftCasefileMapper {

    private final ObjectMapper objectMapper;

    public DraftCasefileEntity toEntity(DraftCasefileAddRequest request, MaintenanceUser user, Instant submittedAt) {
        LocalDateTime timestamp = LocalDateTime.ofInstant(submittedAt, ZoneOffset.UTC);
        DraftCasefileSubmissionTimelineEntry event = new DraftCasefileSubmissionTimelineEntry()
            .username(user.displayName())
            .status(DraftCasefileSubmissionTimelineEntry.StatusEnum.SUBMITTED)
            .statusDate(submittedAt.atOffset(ZoneOffset.UTC));
        try {
            return DraftCasefileEntity.builder()
                .businessUnitId(request.getBusinessUnitId())
                .createdDate(timestamp)
                .submittedBy(user.businessUnitUserId())
                .submittedByName(user.displayName())
                .casefile(request.getCasefile().toString())
                .casefileSnapshot(objectMapper.writeValueAsString(snapshot(request.getCasefile())))
                .casefileType(request.getCasefileType().getValue())
                .casefileStatus(DraftCasefileStatus.SUBMITTED)
                .casefileStatusDate(timestamp)
                .timelineData(objectMapper.writeValueAsString(List.of(event)))
                .build();
        } catch (JsonProcessingException exception) {
            throw new IllegalStateException("Unable to serialize Draft Casefile metadata", exception);
        }
    }

    public DraftCasefileAddResponse toResponse(DraftCasefileEntity entity) {
        try {
            return new DraftCasefileAddResponse()
                .draftCasefileId(entity.getDraftCasefileId())
                .businessUnitId(entity.getBusinessUnitId())
                .createdDate(entity.getCreatedDate().atOffset(ZoneOffset.UTC))
                .submittedBy(entity.getSubmittedBy())
                .submittedByName(entity.getSubmittedByName())
                .casefileSnapshot(objectMapper.readValue(entity.getCasefileSnapshot(), CasefileSnapshot.class))
                .casefileType(CasefileType.fromValue(entity.getCasefileType()))
                .casefileStatus(DraftCasefileAddResponse.CasefileStatusEnum
                    .fromValue(entity.getCasefileStatus().name()))
                .casefileStatusDate(entity.getCasefileStatusDate().atOffset(ZoneOffset.UTC))
                .timelineData(objectMapper.readValue(entity.getTimelineData(),
                    new TypeReference<List<DraftCasefileSubmissionTimelineEntry>>() {}));
        } catch (JsonProcessingException exception) {
            throw new IllegalStateException("Unable to deserialize Draft Casefile metadata", exception);
        }
    }

    private static CasefileSnapshot snapshot(JsonNode casefile) {
        return new CasefileSnapshot()
            .respondentAccount(CasefileSnapshotRespondentAccount.builder()
                .accountId(JsonNullable.of(null))
                .accountNumber(JsonNullable.of(null))
                .respondentName(displayName(casefile.at("/respondent_account/respondent/party_details")))
                .build())
            .applicantAccount(CasefileSnapshotApplicantAccount.builder()
                .accountId(JsonNullable.of(null))
                .accountNumber(JsonNullable.of(null))
                .applicantName(displayName(casefile.at("/applicant/party_details")))
                .build())
            .minorCreditorAccounts(minorCreditors(casefile));
    }

    private static List<CasefileSnapshotMinorCreditorAccount> minorCreditors(JsonNode casefile) {
        List<CasefileSnapshotMinorCreditorAccount> accounts = new ArrayList<>();
        for (JsonNode creditor : casefile.path("minor_creditors")) {
            accounts.add(CasefileSnapshotMinorCreditorAccount.builder()
                .creditorSequence(creditor.get("creditor_sequence").intValue())
                .accountId(JsonNullable.of(null))
                .accountNumber(JsonNullable.of(null))
                .name(displayName(creditor.get("party_details")))
                .build());
        }
        return accounts;
    }

    private static String displayName(JsonNode party) {
        if (party.get("organisation").booleanValue()) {
            return party.get("organisation_details").get("organisation_name").asString();
        }
        JsonNode person = party.get("individual_details");
        String surname = person.get("surname").asString().toUpperCase(Locale.ROOT);
        String forenames = person.path("forenames").asString("");
        return forenames.isBlank() ? surname : surname + ", " + forenames;
    }
}
