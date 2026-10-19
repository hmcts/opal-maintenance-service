package uk.gov.hmcts.opal.entity;

import jakarta.annotation.Generated;
import jakarta.persistence.metamodel.EntityType;
import jakarta.persistence.metamodel.SingularAttribute;
import jakarta.persistence.metamodel.StaticMetamodel;

/**
 * Static metamodel for {@link uk.gov.hmcts.opal.entity.MaintenanceApplicationEntity}
 **/
@StaticMetamodel(MaintenanceApplicationEntity.class)
@Generated("org.hibernate.processor.HibernateProcessor")
public abstract class MaintenanceApplicationEntity_ {

	
	/**
	 * @see #applicationId
	 **/
	public static final String APPLICATION_ID = "applicationId";
	
	/**
	 * @see #applicationCode
	 **/
	public static final String APPLICATION_CODE = "applicationCode";
	
	/**
	 * @see #applicationTitle
	 **/
	public static final String APPLICATION_TITLE = "applicationTitle";
	
	/**
	 * @see #applicationGroup
	 **/
	public static final String APPLICATION_GROUP = "applicationGroup";
	
	/**
	 * @see #active
	 **/
	public static final String ACTIVE = "active";

	
	/**
	 * Static metamodel type for {@link uk.gov.hmcts.opal.entity.MaintenanceApplicationEntity}
	 **/
	public static volatile EntityType<MaintenanceApplicationEntity> class_;
	
	/**
	 * Static metamodel for attribute {@link uk.gov.hmcts.opal.entity.MaintenanceApplicationEntity#applicationId}
	 **/
	public static volatile SingularAttribute<MaintenanceApplicationEntity, Short> applicationId;
	
	/**
	 * Static metamodel for attribute {@link uk.gov.hmcts.opal.entity.MaintenanceApplicationEntity#applicationCode}
	 **/
	public static volatile SingularAttribute<MaintenanceApplicationEntity, String> applicationCode;
	
	/**
	 * Static metamodel for attribute {@link uk.gov.hmcts.opal.entity.MaintenanceApplicationEntity#applicationTitle}
	 **/
	public static volatile SingularAttribute<MaintenanceApplicationEntity, String> applicationTitle;
	
	/**
	 * Static metamodel for attribute {@link uk.gov.hmcts.opal.entity.MaintenanceApplicationEntity#applicationGroup}
	 **/
	public static volatile SingularAttribute<MaintenanceApplicationEntity, String> applicationGroup;
	
	/**
	 * Static metamodel for attribute {@link uk.gov.hmcts.opal.entity.MaintenanceApplicationEntity#active}
	 **/
	public static volatile SingularAttribute<MaintenanceApplicationEntity, Boolean> active;

}

