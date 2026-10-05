/**
 * OPAL Program
 *
 * MODULE      : V1_17__insert_configuration_items_data.sql
 *
 * DESCRIPTION : Load the two approved global clearance settings from
 *               rm/common/reference-data/configuration-items.csv.
 *               Generate RM IDs, preserve existing IDs and unrelated scopes,
 *               and correct only changed approved target values.
 *
 * CHANGE HISTORY:
 *
 * Date        Author        Ticket        Nature of Change
 * ----------  ------------  ------------  ----------------------------------------
 * 03/10/2026  Chris Larkin  PO-10636      Load global clearance configuration.
 */

INSERT INTO public.configuration_items AS current_item
    (item_name, business_unit_id, item_value, item_values)
VALUES
    ('DEFAULT_CHEQUE_CLEARANCE_PERIOD', NULL, '10', NULL),
    ('DEFAULT_CREDIT_TRANS_CLEARANCE_PERIOD', NULL, '0', NULL)
ON CONFLICT ON CONSTRAINT configuration_items_item_name_business_unit_id_uk
DO UPDATE SET item_value = EXCLUDED.item_value,
              item_values = EXCLUDED.item_values
WHERE current_item.item_value IS DISTINCT FROM EXCLUDED.item_value
   OR current_item.item_values IS NOT NULL;
