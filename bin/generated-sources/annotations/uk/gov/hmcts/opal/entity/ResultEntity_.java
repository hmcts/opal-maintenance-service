package uk.gov.hmcts.opal.entity;

import jakarta.persistence.metamodel.EntityType;
import jakarta.persistence.metamodel.SingularAttribute;
import jakarta.persistence.metamodel.StaticMetamodel;

/**
 * Static metamodel for {@link uk.gov.hmcts.opal.entity.ResultEntity}
 **/
@StaticMetamodel(ResultEntity.class)
public abstract class ResultEntity_ {

	
	/**
	 * @see #resultId
	 **/
	public static final String RESULT_ID = "resultId";
	
	/**
	 * @see #resultTitle
	 **/
	public static final String RESULT_TITLE = "resultTitle";
	
	/**
	 * @see #resultParameters
	 **/
	public static final String RESULT_PARAMETERS = "resultParameters";
	
	/**
	 * @see #orderTerm
	 **/
	public static final String ORDER_TERM = "orderTerm";
	
	/**
	 * @see #requiresCreditor
	 **/
	public static final String REQUIRES_CREDITOR = "requiresCreditor";
	
	/**
	 * @see #active
	 **/
	public static final String ACTIVE = "active";

	
	/**
	 * Static metamodel type for {@link uk.gov.hmcts.opal.entity.ResultEntity}
	 **/
	public static volatile EntityType<ResultEntity> class_;
	
	/**
	 * Static metamodel for attribute {@link uk.gov.hmcts.opal.entity.ResultEntity#resultId}
	 **/
	public static volatile SingularAttribute<ResultEntity, String> resultId;
	
	/**
	 * Static metamodel for attribute {@link uk.gov.hmcts.opal.entity.ResultEntity#resultTitle}
	 **/
	public static volatile SingularAttribute<ResultEntity, String> resultTitle;
	
	/**
	 * Static metamodel for attribute {@link uk.gov.hmcts.opal.entity.ResultEntity#resultParameters}
	 **/
	public static volatile SingularAttribute<ResultEntity, String> resultParameters;
	
	/**
	 * Static metamodel for attribute {@link uk.gov.hmcts.opal.entity.ResultEntity#orderTerm}
	 **/
	public static volatile SingularAttribute<ResultEntity, Boolean> orderTerm;
	
	/**
	 * Static metamodel for attribute {@link uk.gov.hmcts.opal.entity.ResultEntity#requiresCreditor}
	 **/
	public static volatile SingularAttribute<ResultEntity, Boolean> requiresCreditor;
	
	/**
	 * Static metamodel for attribute {@link uk.gov.hmcts.opal.entity.ResultEntity#active}
	 **/
	public static volatile SingularAttribute<ResultEntity, Boolean> active;

}

