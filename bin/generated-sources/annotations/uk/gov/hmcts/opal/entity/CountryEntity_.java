package uk.gov.hmcts.opal.entity;

import jakarta.annotation.Generated;
import jakarta.persistence.metamodel.EntityType;
import jakarta.persistence.metamodel.SingularAttribute;
import jakarta.persistence.metamodel.StaticMetamodel;
import java.time.LocalDate;

/**
 * Static metamodel for {@link uk.gov.hmcts.opal.entity.CountryEntity}
 **/
@StaticMetamodel(CountryEntity.class)
@Generated("org.hibernate.processor.HibernateProcessor")
public abstract class CountryEntity_ {

	
	/**
	 * @see #countryId
	 **/
	public static final String COUNTRY_ID = "countryId";
	
	/**
	 * @see #cjsCode
	 **/
	public static final String CJS_CODE = "cjsCode";
	
	/**
	 * @see #internationalCode
	 **/
	public static final String INTERNATIONAL_CODE = "internationalCode";
	
	/**
	 * @see #govCode
	 **/
	public static final String GOV_CODE = "govCode";
	
	/**
	 * @see #countryName
	 **/
	public static final String COUNTRY_NAME = "countryName";
	
	/**
	 * @see #demonym
	 **/
	public static final String DEMONYM = "demonym";
	
	/**
	 * @see #dateUsedFrom
	 **/
	public static final String DATE_USED_FROM = "dateUsedFrom";
	
	/**
	 * @see #dateUsedTo
	 **/
	public static final String DATE_USED_TO = "dateUsedTo";
	
	/**
	 * @see #active
	 **/
	public static final String ACTIVE = "active";

	
	/**
	 * Static metamodel type for {@link uk.gov.hmcts.opal.entity.CountryEntity}
	 **/
	public static volatile EntityType<CountryEntity> class_;
	
	/**
	 * Static metamodel for attribute {@link uk.gov.hmcts.opal.entity.CountryEntity#countryId}
	 **/
	public static volatile SingularAttribute<CountryEntity, Long> countryId;
	
	/**
	 * Static metamodel for attribute {@link uk.gov.hmcts.opal.entity.CountryEntity#cjsCode}
	 **/
	public static volatile SingularAttribute<CountryEntity, Short> cjsCode;
	
	/**
	 * Static metamodel for attribute {@link uk.gov.hmcts.opal.entity.CountryEntity#internationalCode}
	 **/
	public static volatile SingularAttribute<CountryEntity, String> internationalCode;
	
	/**
	 * Static metamodel for attribute {@link uk.gov.hmcts.opal.entity.CountryEntity#govCode}
	 **/
	public static volatile SingularAttribute<CountryEntity, String> govCode;
	
	/**
	 * Static metamodel for attribute {@link uk.gov.hmcts.opal.entity.CountryEntity#countryName}
	 **/
	public static volatile SingularAttribute<CountryEntity, String> countryName;
	
	/**
	 * Static metamodel for attribute {@link uk.gov.hmcts.opal.entity.CountryEntity#demonym}
	 **/
	public static volatile SingularAttribute<CountryEntity, String> demonym;
	
	/**
	 * Static metamodel for attribute {@link uk.gov.hmcts.opal.entity.CountryEntity#dateUsedFrom}
	 **/
	public static volatile SingularAttribute<CountryEntity, LocalDate> dateUsedFrom;
	
	/**
	 * Static metamodel for attribute {@link uk.gov.hmcts.opal.entity.CountryEntity#dateUsedTo}
	 **/
	public static volatile SingularAttribute<CountryEntity, LocalDate> dateUsedTo;
	
	/**
	 * Static metamodel for attribute {@link uk.gov.hmcts.opal.entity.CountryEntity#active}
	 **/
	public static volatile SingularAttribute<CountryEntity, Boolean> active;

}

