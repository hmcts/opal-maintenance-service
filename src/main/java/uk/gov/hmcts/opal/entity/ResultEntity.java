package uk.gov.hmcts.opal.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

@Entity
@Table(name = "results")
@Getter
@Builder
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@AllArgsConstructor(access = AccessLevel.PRIVATE)
public class ResultEntity {

    @Id
    @Column(name = "result_id", nullable = false, length = 6)
    private String resultId;

    @Column(name = "result_title", nullable = false, length = 60)
    private String resultTitle;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "result_parameters", columnDefinition = "json")
    private String resultParameters;

    @Column(name = "order_term", nullable = false)
    private Boolean orderTerm;

    @Column(name = "active", nullable = false)
    private Boolean active;
}
