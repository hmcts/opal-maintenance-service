package uk.gov.hmcts.opal.mapper;

import com.fasterxml.jackson.core.JsonProcessingException;
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
import uk.gov.hmcts.opal.generated.model.DraftCasefileAddRequest;
import uk.gov.hmcts.opal.generated.model.DraftCasefileReplaceRequest;
import uk.gov.hmcts.opal.generated.model.DraftCasefileUpdateRequest;
import uk.gov.hmcts.opal.generated.model.CasefileTimelineEntry;
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
    private final DraftCasefileJsonMapper jsonMapper;

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

    public DraftCasefileEntity toResubmittedEntity(DraftCasefileEntity existing,
                                                  DraftCasefileReplaceRequest request,
                                                  MaintenanceUser user, Instant resubmittedAt) {
        List<CasefileTimelineEntry> timeline = new ArrayList<>(jsonMapper.readTimeline(existing.getTimelineData()));
        timeline.add(new CasefileTimelineEntry().username(user.displayName())
            .status(CasefileTimelineEntry.StatusEnum.RESUBMITTED)
            .statusDate(resubmittedAt.atOffset(ZoneOffset.UTC)));
        try {
            return existing.toBuilder()
                .casefile(request.getCasefile().toString())
                .casefileSnapshot(objectMapper.writeValueAsString(snapshot(request.getCasefile())))
                .submittedBy(user.businessUnitUserId())
                .submittedByName(user.displayName())
                .casefileStatus(DraftCasefileStatus.RESUBMITTED)
                .casefileStatusDate(LocalDateTime.ofInstant(resubmittedAt, ZoneOffset.UTC))
                .timelineData(objectMapper.writeValueAsString(timeline))
                .build();
        } catch (JsonProcessingException exception) {
            throw new IllegalStateException("Unable to serialize Draft Casefile metadata");
        }
    }

    public DraftCasefileEntity toDecidedEntity(DraftCasefileEntity existing,
                                               DraftCasefileUpdateRequest request,
                                               MaintenanceUser user, Instant decidedAt) {
        DraftCasefileStatus status = DraftCasefileStatus.valueOf(request.getCasefileStatus().name());
        CasefileTimelineEntry.StatusEnum timelineStatus = switch (request.getCasefileStatus()) {
            case PUBLISHING_PENDING -> CasefileTimelineEntry.StatusEnum.APPROVED;
            case REJECTED -> CasefileTimelineEntry.StatusEnum.REJECTED;
            case DELETED -> CasefileTimelineEntry.StatusEnum.DELETED;
        };
        List<CasefileTimelineEntry> timeline = new ArrayList<>(jsonMapper.readTimeline(existing.getTimelineData()));
        timeline.add(new CasefileTimelineEntry().username(user.displayName()).status(timelineStatus)
            .statusDate(decidedAt.atOffset(ZoneOffset.UTC)).reasonText(request.getStatusMessage()));
        LocalDateTime timestamp = LocalDateTime.ofInstant(decidedAt, ZoneOffset.UTC);
        try {
            var updated = existing.toBuilder().casefileStatus(status).casefileStatusDate(timestamp)
                .statusMessage(request.getStatusMessage()).timelineData(objectMapper.writeValueAsString(timeline));
            if (status == DraftCasefileStatus.PUBLISHING_PENDING) {
                updated.validatedBy(user.businessUnitUserId()).validatedByName(user.displayName())
                    .validatedDate(timestamp).statusMessage(null);
            }
            return updated.build();
        } catch (JsonProcessingException exception) {
            throw new IllegalStateException("Unable to serialize Draft Casefile metadata");
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
