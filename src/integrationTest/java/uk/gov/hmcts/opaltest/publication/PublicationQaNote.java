package uk.gov.hmcts.opaltest.publication;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.util.Arrays;
import java.util.List;
import org.hibernate.annotations.ColumnTransformer;

import java.time.LocalDateTime;

/** Scalar test mapping; deliberately outside the application entity-scan package. */
@Entity
@Table(name = "notes")
public class PublicationQaNote {

    @Id
    @Column(name = "note_id", nullable = false)
    private Long noteId;

    // PostgreSQL enum binding for the observer regression fixture; reads remain scalar Strings.
    @ColumnTransformer(write = "?::public.t_note_type_enum")
    @Column(name = "note_type", nullable = false, columnDefinition = "public.t_note_type_enum")
    private String noteType;

    // PostgreSQL enum binding for the observer regression fixture; reads remain scalar Strings.
    @ColumnTransformer(write = "?::public.t_associated_record_type_enum")
    @Column(name = "associated_record_type", nullable = false,
        columnDefinition = "public.t_associated_record_type_enum")
    private String associatedRecordType;

    @Column(name = "associated_record_id", nullable = false, length = 30)
    private String associatedRecordId;

    @Column(name = "note_text", nullable = false, columnDefinition = "text")
    private String noteText;

    @Column(name = "posted_date", nullable = false)
    private LocalDateTime postedDate;

    @Column(name = "posted_by", length = 20)
    private String postedBy;

    @Column(name = "posted_by_name", length = 100)
    private String postedByName;

    protected PublicationQaNote() {
    }

    private PublicationQaNote(PublicationQaNote source) {
        noteId = source.noteId;
        noteType = source.noteType;
        associatedRecordType = source.associatedRecordType;
        associatedRecordId = source.associatedRecordId;
        noteText = source.noteText;
        postedDate = source.postedDate;
        postedBy = source.postedBy;
        postedByName = source.postedByName;
    }

    public Long getNoteId() {
        return noteId;
    }

    public String getNoteType() {
        return noteType;
    }

    public String getAssociatedRecordType() {
        return associatedRecordType;
    }

    public String getAssociatedRecordId() {
        return associatedRecordId;
    }

    public String getNoteText() {
        return noteText;
    }

    public LocalDateTime getPostedDate() {
        return postedDate;
    }

    public String getPostedBy() {
        return postedBy;
    }

    public String getPostedByName() {
        return postedByName;
    }

    public static Builder builder() {
        return new Builder(new PublicationQaNote());
    }

    public Builder toBuilder() {
        return new Builder(new PublicationQaNote(this));
    }

    @Override
    public boolean equals(Object other) {
        return other instanceof PublicationQaNote row && scalarValues().equals(row.scalarValues());
    }

    @Override
    public int hashCode() {
        return scalarValues().hashCode();
    }

    private List<Object> scalarValues() {
        return Arrays.asList(
            noteId, noteType, associatedRecordType,
            associatedRecordId, noteText, postedDate,
            postedBy, postedByName
        );
    }

    public static final class Builder {
        private final PublicationQaNote value;

        private Builder(PublicationQaNote value) {
            this.value = value;
        }

        public Builder noteId(Long field) {
            value.noteId = field;
            return this;
        }

        public Builder noteType(String field) {
            value.noteType = field;
            return this;
        }

        public Builder associatedRecordType(String field) {
            value.associatedRecordType = field;
            return this;
        }

        public Builder associatedRecordId(String field) {
            value.associatedRecordId = field;
            return this;
        }

        public Builder noteText(String field) {
            value.noteText = field;
            return this;
        }

        public Builder postedDate(LocalDateTime field) {
            value.postedDate = field;
            return this;
        }

        public Builder postedBy(String field) {
            value.postedBy = field;
            return this;
        }

        public Builder postedByName(String field) {
            value.postedByName = field;
            return this;
        }

        public PublicationQaNote build() {
            return new PublicationQaNote(value);
        }
    }
}
