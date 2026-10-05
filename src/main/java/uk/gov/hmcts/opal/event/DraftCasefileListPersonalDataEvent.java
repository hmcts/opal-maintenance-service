package uk.gov.hmcts.opal.event;

import uk.gov.hmcts.opal.event.DraftCasefilePersonalDataEvent.ParticipantCategory;

import java.time.Instant;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;

public record DraftCasefileListPersonalDataEvent(Long userId, String ipAddress, Instant occurredAt,
                                                Map<ParticipantCategory, List<Long>> draftIdsByCategory) {
    public DraftCasefileListPersonalDataEvent {
        Map<ParticipantCategory, List<Long>> copy = new EnumMap<>(ParticipantCategory.class);
        draftIdsByCategory.forEach((category, ids) -> {
            List<Long> uniqueIds = ids.stream().distinct().toList();
            if (!uniqueIds.isEmpty()) {
                copy.put(category, uniqueIds);
            }
        });
        draftIdsByCategory = Map.copyOf(copy);
    }
}
