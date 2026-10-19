package uk.gov.hmcts.opal.entity;

import jakarta.annotation.Generated;
import jakarta.persistence.metamodel.EntityType;
import jakarta.persistence.metamodel.SingularAttribute;
import jakarta.persistence.metamodel.StaticMetamodel;

/**
 * Static metamodel for {@link uk.gov.hmcts.opal.entity.MajorCreditorEntity}
 **/
@StaticMetamodel(MajorCreditorEntity.class)
@Generated("org.hibernate.processor.HibernateProcessor")
public abstract class MajorCreditorEntity_ {

	
	/**
	 * @see #majorCreditorId
	 **/
	public static final String MAJOR_CREDITOR_ID = "majorCreditorId";
	
	/**
	 * @see #businessUnitId
	 **/
	public static final String BUSINESS_UNIT_ID = "businessUnitId";
	
	/**
	 * @see #majorCreditorCode
	 **/
	public static final String MAJOR_CREDITOR_CODE = "majorCreditorCode";
	
	/**
	 * @see #name
	 **/
	public static final String NAME = "name";
	
	/**
	 * @see #addressLine1
	 **/
	public static final String ADDRESS_LINE1 = "addressLine1";
	
	/**
	 * @see #addressLine2
	 **/
	public static final String ADDRESS_LINE2 = "addressLine2";
	
	/**
	 * @see #addressLine3
	 **/
	public static final String ADDRESS_LINE3 = "addressLine3";
	
	/**
	 * @see #addressLine4
	 **/
	public static final String ADDRESS_LINE4 = "addressLine4";
	
	/**
	 * @see #addressLine5
	 **/
	public static final String ADDRESS_LINE5 = "addressLine5";
	
	/**
	 * @see #postcode
	 **/
	public static final String POSTCODE = "postcode";
	
	/**
	 * @see #country
	 **/
	public static final String COUNTRY = "country";
	
	/**
	 * @see #contactName
	 **/
	public static final String CONTACT_NAME = "contactName";
	
	/**
	 * @see #contactEmail
	 **/
	public static final String CONTACT_EMAIL = "contactEmail";
	
	/**
	 * @see #active
	 **/
	public static final String ACTIVE = "active";
	
	/**
	 * @see #centralAuthority
	 **/
	public static final String CENTRAL_AUTHORITY = "centralAuthority";

	
	/**
	 * Static metamodel type for {@link uk.gov.hmcts.opal.entity.MajorCreditorEntity}
	 **/
	public static volatile EntityType<MajorCreditorEntity> class_;
	
	/**
	 * Static metamodel for attribute {@link uk.gov.hmcts.opal.entity.MajorCreditorEntity#majorCreditorId}
	 **/
	public static volatile SingularAttribute<MajorCreditorEntity, Long> majorCreditorId;
	
	/**
	 * Static metamodel for attribute {@link uk.gov.hmcts.opal.entity.MajorCreditorEntity#businessUnitId}
	 **/
	public static volatile SingularAttribute<MajorCreditorEntity, Short> businessUnitId;
	
	/**
	 * Static metamodel for attribute {@link uk.gov.hmcts.opal.entity.MajorCreditorEntity#majorCreditorCode}
	 **/
	public static volatile SingularAttribute<MajorCreditorEntity, String> majorCreditorCode;
	
	/**
	 * Static metamodel for attribute {@link uk.gov.hmcts.opal.entity.MajorCreditorEntity#name}
	 **/
	public static volatile SingularAttribute<MajorCreditorEntity, String> name;
	
	/**
	 * Static metamodel for attribute {@link uk.gov.hmcts.opal.entity.MajorCreditorEntity#addressLine1}
	 **/
	public static volatile SingularAttribute<MajorCreditorEntity, String> addressLine1;
	
	/**
	 * Static metamodel for attribute {@link uk.gov.hmcts.opal.entity.MajorCreditorEntity#addressLine2}
	 **/
	public static volatile SingularAttribute<MajorCreditorEntity, String> addressLine2;
	
	/**
	 * Static metamodel for attribute {@link uk.gov.hmcts.opal.entity.MajorCreditorEntity#addressLine3}
	 **/
	public static volatile SingularAttribute<MajorCreditorEntity, String> addressLine3;
	
	/**
	 * Static metamodel for attribute {@link uk.gov.hmcts.opal.entity.MajorCreditorEntity#addressLine4}
	 **/
	public static volatile SingularAttribute<MajorCreditorEntity, String> addressLine4;
	
	/**
	 * Static metamodel for attribute {@link uk.gov.hmcts.opal.entity.MajorCreditorEntity#addressLine5}
	 **/
	public static volatile SingularAttribute<MajorCreditorEntity, String> addressLine5;
	
	/**
	 * Static metamodel for attribute {@link uk.gov.hmcts.opal.entity.MajorCreditorEntity#postcode}
	 **/
	public static volatile SingularAttribute<MajorCreditorEntity, String> postcode;
	
	/**
	 * Static metamodel for attribute {@link uk.gov.hmcts.opal.entity.MajorCreditorEntity#country}
	 **/
	public static volatile SingularAttribute<MajorCreditorEntity, CountryEntity> country;
	
	/**
	 * Static metamodel for attribute {@link uk.gov.hmcts.opal.entity.MajorCreditorEntity#contactName}
	 **/
	public static volatile SingularAttribute<MajorCreditorEntity, String> contactName;
	
	/**
	 * Static metamodel for attribute {@link uk.gov.hmcts.opal.entity.MajorCreditorEntity#contactEmail}
	 **/
	public static volatile SingularAttribute<MajorCreditorEntity, String> contactEmail;
	
	/**
	 * Static metamodel for attribute {@link uk.gov.hmcts.opal.entity.MajorCreditorEntity#active}
	 **/
	public static volatile SingularAttribute<MajorCreditorEntity, Boolean> active;
	
	/**
	 * Static metamodel for attribute {@link uk.gov.hmcts.opal.entity.MajorCreditorEntity#centralAuthority}
	 **/
	public static volatile SingularAttribute<MajorCreditorEntity, Boolean> centralAuthority;

}

