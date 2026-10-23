package uk.gov.hmcts.opal.service;

import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import uk.gov.hmcts.opal.authorisation.MaintenanceUser;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;
import uk.gov.hmcts.opal.entity.DraftCasefileStatus;
import uk.gov.hmcts.opal.generated.model.CasefileTimelineEntry;
import uk.gov.hmcts.opal.generated.model.DraftCasefileReplaceRequest;
import uk.gov.hmcts.opal.generated.model.DraftCasefileUpdateRequest;
import uk.gov.hmcts.opal.mapper.DraftCasefileJsonMapper;
import uk.gov.hmcts.opal.mapper.DraftCasefileMapper;

import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;

@Component
@RequiredArgsConstructor
public class DraftCasefileUpdater {

    private final DraftCasefileMapper mapper;
    private final DraftCasefileJsonMapper jsonMapper;

    /** Returns an updated copy of the draft with the resubmission applied. */
    public DraftCasefileEntity applyResubmission(DraftCasefileEntity existing,
                                                 DraftCasefileReplaceRequest request,
                                                 MaintenanceUser user, Instant resubmittedAt) {
        List<CasefileTimelineEntry> timeline = new ArrayList<>(jsonMapper.readTimeline(existing.getTimelineData()));
        timeline.add(new CasefileTimelineEntry().username(user.displayName())
            .status(CasefileTimelineEntry.StatusEnum.RESUBMITTED)
            .statusDate(resubmittedAt.atOffset(ZoneOffset.UTC)));
        return existing.toBuilder()
            .casefile(request.getCasefile().toString())
            .casefileSnapshot(mapper.toSnapshotJson(request.getCasefile()))
            .submittedBy(user.businessUnitUserId())
            .submittedByName(user.displayName())
            .casefileStatus(DraftCasefileStatus.RESUBMITTED)
            .casefileStatusDate(LocalDateTime.ofInstant(resubmittedAt, ZoneOffset.UTC))
            .timelineData(jsonMapper.writeTimeline(timeline))
            .build();
    }

    /** Returns an updated copy of the draft with the checker decision applied. */
    public DraftCasefileEntity applyDecision(DraftCasefileEntity existing,
                                             DraftCasefileUpdateRequest request,
                                             MaintenanceUser user, Instant decidedAt) {
        DraftCasefileStatus status = switch (request.getCasefileStatus()) {
            case PUBLISHING_PENDING -> DraftCasefileStatus.PUBLISHING_PENDING;
            case REJECTED -> DraftCasefileStatus.REJECTED;
            case DELETED -> DraftCasefileStatus.DELETED;
        };
        CasefileTimelineEntry.StatusEnum timelineStatus = switch (request.getCasefileStatus()) {
            case PUBLISHING_PENDING -> CasefileTimelineEntry.StatusEnum.APPROVED;
            case REJECTED -> CasefileTimelineEntry.StatusEnum.REJECTED;
            case DELETED -> CasefileTimelineEntry.StatusEnum.DELETED;
        };
        List<CasefileTimelineEntry> timeline = new ArrayList<>(jsonMapper.readTimeline(existing.getTimelineData()));
        timeline.add(new CasefileTimelineEntry().username(user.displayName()).status(timelineStatus)
            .statusDate(decidedAt.atOffset(ZoneOffset.UTC)).reasonText(request.getStatusMessage()));
        LocalDateTime timestamp = LocalDateTime.ofInstant(decidedAt, ZoneOffset.UTC);
        var updated = existing.toBuilder().casefileStatus(status).casefileStatusDate(timestamp)
            .statusMessage(request.getStatusMessage()).timelineData(jsonMapper.writeTimeline(timeline));
        if (status == DraftCasefileStatus.PUBLISHING_PENDING) {
            updated.validatedBy(user.businessUnitUserId()).validatedByName(user.displayName())
                .validatedDate(timestamp).statusMessage(null);
        }
        return updated.build();
    }
}
