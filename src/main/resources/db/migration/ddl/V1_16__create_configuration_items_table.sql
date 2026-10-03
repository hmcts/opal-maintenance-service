/**
 * OPAL Program
 *
 * MODULE      : V1_16__create_configuration_items_table.sql
 *
 * DESCRIPTION : Create global and Business Unit-scoped configuration items.
 *
 * CHANGE HISTORY:
 *
 * Date        Author        Ticket        Nature of Change
 * ----------  ------------  ------------  ----------------------------------------
 * 03/10/2026  Codex         PO-10638      Create approved database object.
 */

CREATE SEQUENCE public.configuration_item_id_seq AS BIGINT START WITH 1 INCREMENT BY 1 NO CYCLE CACHE 1;

CREATE TABLE public.configuration_items (
    configuration_item_id  BIGINT DEFAULT nextval('public.configuration_item_id_seq'::regclass) NOT NULL,
    item_name              VARCHAR(50)                                                          NOT NULL,
    business_unit_id       SMALLINT,
    item_value             TEXT,
    item_values            JSON,
    CONSTRAINT configuration_items_pk PRIMARY KEY (configuration_item_id),
    CONSTRAINT ci_business_unit_id_fk FOREIGN KEY (business_unit_id) REFERENCES public.business_units (business_unit_id),
    CONSTRAINT configuration_items_item_name_business_unit_id_uk UNIQUE NULLS NOT DISTINCT (item_name, business_unit_id)
);
ALTER SEQUENCE public.configuration_item_id_seq OWNED BY public.configuration_items.configuration_item_id;
CREATE INDEX ci_business_unit_id_idx ON public.configuration_items USING btree (business_unit_id);

COMMENT ON COLUMN public.configuration_items.configuration_item_id IS 'RM-generated configuration-item identifier';
COMMENT ON COLUMN public.configuration_items.item_name IS 'Configuration-item name, unique within its global or Business Unit scope';
COMMENT ON COLUMN public.configuration_items.business_unit_id IS 'Identifier of the related Business Unit, or NULL for a global value';
COMMENT ON COLUMN public.configuration_items.item_value IS 'Single text value';
COMMENT ON COLUMN public.configuration_items.item_values IS 'Multiple or structured values';
