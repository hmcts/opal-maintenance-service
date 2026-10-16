package uk.gov.hmcts.opal.mapper;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import uk.gov.hmcts.opal.dto.TestingSupportDraftCasefileMetadata;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;

import java.time.ZoneOffset;
import java.util.List;
import java.util.stream.StreamSupport;

@Component
@RequiredArgsConstructor
public class TestingSupportDraftCasefileMapper {

    private final ObjectMapper objectMapper;

    public TestingSupportDraftCasefileMetadata toMetadata(DraftCasefileEntity entity) {
        JsonNode snapshot = read(entity.getCasefileSnapshot(), entity.getDraftCasefileId());
        JsonNode timeline = read(entity.getTimelineData(), entity.getDraftCasefileId());
        List<String> statuses = StreamSupport.stream(timeline.spliterator(), false)
            .map(item -> item.path("status").asText())
            .toList();
        return new TestingSupportDraftCasefileMetadata(
            entity.getDraftCasefileId(), entity.getBusinessUnitId(), entity.getSubmittedBy(),
            entity.getCreatedDate().atOffset(ZoneOffset.UTC), entity.getCasefileStatus(),
            entity.getCasefileStatusDate().atOffset(ZoneOffset.UTC), entity.getVersionNumber(),
            !snapshot.isNull() && !snapshot.isMissingNode(), timeline.size(), statuses);
    }

    public String marker(DraftCasefileEntity entity) {
        JsonNode marker = read(entity.getCasefile(), entity.getDraftCasefileId())
            .at("/respondent_account/account_comment");
        return marker.isTextual() ? marker.asText() : null;
    }

    private JsonNode read(String value, Long draftId) {
        try {
            return objectMapper.readTree(value);
        } catch (JsonProcessingException exception) {
            throw new IllegalStateException("Malformed persisted Draft Casefile JSON for draft ID " + draftId);
        }
    }
}
