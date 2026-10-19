package uk.gov.hmcts.opal.entity;

import jakarta.persistence.metamodel.EntityType;
import jakarta.persistence.metamodel.SingularAttribute;
import jakarta.persistence.metamodel.StaticMetamodel;
import java.time.LocalDateTime;

/**
 * Static metamodel for {@link uk.gov.hmcts.opal.entity.DraftCasefileEntity}
 **/
@StaticMetamodel(DraftCasefileEntity.class)
public abstract class DraftCasefileEntity_ {

	
	/**
	 * @see #draftCasefileId
	 **/
	public static final String DRAFT_CASEFILE_ID = "draftCasefileId";
	
	/**
	 * @see #businessUnitId
	 **/
	public static final String BUSINESS_UNIT_ID = "businessUnitId";
	
	/**
	 * @see #createdDate
	 **/
	public static final String CREATED_DATE = "createdDate";
	
	/**
	 * @see #submittedBy
	 **/
	public static final String SUBMITTED_BY = "submittedBy";
	
	/**
	 * @see #submittedByName
	 **/
	public static final String SUBMITTED_BY_NAME = "submittedByName";
	
	/**
	 * @see #validatedDate
	 **/
	public static final String VALIDATED_DATE = "validatedDate";
	
	/**
	 * @see #validatedBy
	 **/
	public static final String VALIDATED_BY = "validatedBy";
	
	/**
	 * @see #validatedByName
	 **/
	public static final String VALIDATED_BY_NAME = "validatedByName";
	
	/**
	 * @see #casefile
	 **/
	public static final String CASEFILE = "casefile";
	
	/**
	 * @see #casefileSnapshot
	 **/
	public static final String CASEFILE_SNAPSHOT = "casefileSnapshot";
	
	/**
	 * @see #casefileType
	 **/
	public static final String CASEFILE_TYPE = "casefileType";
	
	/**
	 * @see #casefileStatus
	 **/
	public static final String CASEFILE_STATUS = "casefileStatus";
	
	/**
	 * @see #casefileStatusDate
	 **/
	public static final String CASEFILE_STATUS_DATE = "casefileStatusDate";
	
	/**
	 * @see #statusMessage
	 **/
	public static final String STATUS_MESSAGE = "statusMessage";
	
	/**
	 * @see #timelineData
	 **/
	public static final String TIMELINE_DATA = "timelineData";
	
	/**
	 * @see #accountNumber
	 **/
	public static final String ACCOUNT_NUMBER = "accountNumber";
	
	/**
	 * @see #accountId
	 **/
	public static final String ACCOUNT_ID = "accountId";
	
	/**
	 * @see #versionNumber
	 **/
	public static final String VERSION_NUMBER = "versionNumber";

	
	/**
	 * Static metamodel type for {@link uk.gov.hmcts.opal.entity.DraftCasefileEntity}
	 **/
	public static volatile EntityType<DraftCasefileEntity> class_;
	
	/**
	 * Static metamodel for attribute {@link uk.gov.hmcts.opal.entity.DraftCasefileEntity#draftCasefileId}
	 **/
	public static volatile SingularAttribute<DraftCasefileEntity, Long> draftCasefileId;
	
	/**
	 * Static metamodel for attribute {@link uk.gov.hmcts.opal.entity.DraftCasefileEntity#businessUnitId}
	 **/
	public static volatile SingularAttribute<DraftCasefileEntity, Short> businessUnitId;
	
	/**
	 * Static metamodel for attribute {@link uk.gov.hmcts.opal.entity.DraftCasefileEntity#createdDate}
	 **/
	public static volatile SingularAttribute<DraftCasefileEntity, LocalDateTime> createdDate;
	
	/**
	 * Static metamodel for attribute {@link uk.gov.hmcts.opal.entity.DraftCasefileEntity#submittedBy}
	 **/
	public static volatile SingularAttribute<DraftCasefileEntity, String> submittedBy;
	
	/**
	 * Static metamodel for attribute {@link uk.gov.hmcts.opal.entity.DraftCasefileEntity#submittedByName}
	 **/
	public static volatile SingularAttribute<DraftCasefileEntity, String> submittedByName;
	
	/**
	 * Static metamodel for attribute {@link uk.gov.hmcts.opal.entity.DraftCasefileEntity#validatedDate}
	 **/
	public static volatile SingularAttribute<DraftCasefileEntity, LocalDateTime> validatedDate;
	
	/**
	 * Static metamodel for attribute {@link uk.gov.hmcts.opal.entity.DraftCasefileEntity#validatedBy}
	 **/
	public static volatile SingularAttribute<DraftCasefileEntity, String> validatedBy;
	
	/**
	 * Static metamodel for attribute {@link uk.gov.hmcts.opal.entity.DraftCasefileEntity#validatedByName}
	 **/
	public static volatile SingularAttribute<DraftCasefileEntity, String> validatedByName;
	
	/**
	 * Static metamodel for attribute {@link uk.gov.hmcts.opal.entity.DraftCasefileEntity#casefile}
	 **/
	public static volatile SingularAttribute<DraftCasefileEntity, String> casefile;
	
	/**
	 * Static metamodel for attribute {@link uk.gov.hmcts.opal.entity.DraftCasefileEntity#casefileSnapshot}
	 **/
	public static volatile SingularAttribute<DraftCasefileEntity, String> casefileSnapshot;
	
	/**
	 * Static metamodel for attribute {@link uk.gov.hmcts.opal.entity.DraftCasefileEntity#casefileType}
	 **/
	public static volatile SingularAttribute<DraftCasefileEntity, String> casefileType;
	
	/**
	 * Static metamodel for attribute {@link uk.gov.hmcts.opal.entity.DraftCasefileEntity#casefileStatus}
	 **/
	public static volatile SingularAttribute<DraftCasefileEntity, DraftCasefileStatus> casefileStatus;
	
	/**
	 * Static metamodel for attribute {@link uk.gov.hmcts.opal.entity.DraftCasefileEntity#casefileStatusDate}
	 **/
	public static volatile SingularAttribute<DraftCasefileEntity, LocalDateTime> casefileStatusDate;
	
	/**
	 * Static metamodel for attribute {@link uk.gov.hmcts.opal.entity.DraftCasefileEntity#statusMessage}
	 **/
	public static volatile SingularAttribute<DraftCasefileEntity, String> statusMessage;
	
	/**
	 * Static metamodel for attribute {@link uk.gov.hmcts.opal.entity.DraftCasefileEntity#timelineData}
	 **/
	public static volatile SingularAttribute<DraftCasefileEntity, String> timelineData;
	
	/**
	 * Static metamodel for attribute {@link uk.gov.hmcts.opal.entity.DraftCasefileEntity#accountNumber}
	 **/
	public static volatile SingularAttribute<DraftCasefileEntity, String> accountNumber;
	
	/**
	 * Static metamodel for attribute {@link uk.gov.hmcts.opal.entity.DraftCasefileEntity#accountId}
	 **/
	public static volatile SingularAttribute<DraftCasefileEntity, Long> accountId;
	
	/**
	 * Static metamodel for attribute {@link uk.gov.hmcts.opal.entity.DraftCasefileEntity#versionNumber}
	 **/
	public static volatile SingularAttribute<DraftCasefileEntity, Long> versionNumber;

}

