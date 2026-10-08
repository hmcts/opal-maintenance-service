package uk.gov.hmcts.opal.mapper;

import com.fasterxml.jackson.core.type.TypeReference;
import lombok.RequiredArgsConstructor;
import org.mapstruct.Named;
import org.springframework.stereotype.Component;
import tools.jackson.core.JacksonException;
import tools.jackson.databind.JsonNode;
import uk.gov.hmcts.opal.generated.model.CasefileSnapshot;
import uk.gov.hmcts.opal.generated.model.CasefileTimelineEntry;
import uk.gov.hmcts.opal.generated.model.DraftCasefileSubmissionTimelineEntry;

import java.io.IOException;
import java.util.List;

@Component
@RequiredArgsConstructor
public class DraftCasefileJsonMapper {

    private final tools.jackson.databind.ObjectMapper json;
    private final com.fasterxml.jackson.databind.ObjectMapper compatible;

    @Named("storedCasefile")
    public JsonNode readCasefile(String value) {
        try {
            return json.readTree(value);
        } catch (JacksonException exception) {
            throw unreadableData();
        }
    }

    @Named("storedSnapshot")
    public CasefileSnapshot readSnapshot(String value) {
        try {
            return compatible.readValue(value, CasefileSnapshot.class);
        } catch (IOException exception) {
            throw unreadableData();
        }
    }

    @Named("storedTimeline")
    public List<CasefileTimelineEntry> readTimeline(String value) {
        try {
            return compatible.readValue(value,
                new TypeReference<List<CasefileTimelineEntry>>() { });
        } catch (IOException exception) {
            throw unreadableData();
        }
    }

    @Named("storedSubmissionTimeline")
    public List<DraftCasefileSubmissionTimelineEntry> readSubmissionTimeline(String value) {
        try {
            return compatible.readValue(value,
                new TypeReference<List<DraftCasefileSubmissionTimelineEntry>>() { });
        } catch (IOException exception) {
            throw unreadableData();
        }
    }

    private static IllegalStateException unreadableData() {
        return new IllegalStateException("Unable to read stored Draft Casefile data");
    }
}
