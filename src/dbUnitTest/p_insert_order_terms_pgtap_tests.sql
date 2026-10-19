/**
 * OPAL Program
 *
 * MODULE      : p_insert_order_terms_pgtap_tests.sql
 *
 * DESCRIPTION : Establish the initial Order Terms procedure catalogue contract.
 *               This is intended RED preparation before candidate acceptance.
 *
 * CHANGE HISTORY:
 *
 * Date        Author         Ticket        Nature of Change
 * ----------  -------------  ------------  ----------------------------------------
 * 15/10/2026  Frankie Moran  PO-10646      Initial pgTAP test suite.
 */

\ir framework/upgrade_lifecycle.sql
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT plan(8);

-- -----------------------------------------------------------------------------
-- Scenario: Establish the intended Order Terms procedure catalogue contract.
-- Setup: Fresh disposable migrations; no accepted routine candidate or fixtures.
-- Expected: UTF8 passes; absent procedure leaves the seven routine checks RED.
-- -----------------------------------------------------------------------------
CREATE TEMP TABLE ot_installed AS SELECT TO_REGPROCEDURE(
    'public.p_insert_order_terms(bigint,bigint,character varying,character varying,json)') AS oid;
SELECT ok(CURRENT_SETTING('server_encoding')='UTF8' AND CURRENT_SETTING('client_encoding')='UTF8','UTF8 supports pinned characters');
SELECT ok((SELECT prokind='p' FROM pg_proc WHERE oid=(SELECT oid FROM ot_installed)),'installed object is a procedure');
SELECT ok((SELECT proargtypes=ARRAY['bigint'::REGTYPE::OID,'bigint'::REGTYPE::OID,'varchar'::REGTYPE::OID,
    'varchar'::REGTYPE::OID,'json'::REGTYPE::OID]::OIDVECTOR FROM pg_proc WHERE oid=(SELECT oid FROM ot_installed)),
    'effective five argument types and order');
SELECT ok((SELECT proargnames=ARRAY['pi_respondent_account_id','pi_creditor_account_id','pi_posted_by',
    'pi_posted_by_name','pi_order_term_json'] FROM pg_proc WHERE oid=(SELECT oid FROM ot_installed)),'exact five names');
SELECT ok((SELECT pronargs=5 AND proargmodes IS NULL AND proallargtypes IS NULL AND prorettype='void'::REGTYPE
    FROM pg_proc WHERE oid=(SELECT oid FROM ot_installed)),'all IN with no output');
SELECT ok((SELECT pronargdefaults=0 AND NOT prosecdef AND NOT proisstrict AND provolatile='v' AND proconfig IS NULL
    FROM pg_proc WHERE oid=(SELECT oid FROM ot_installed)),'effective defaults preserve caller ownership');
SELECT ok((SELECT lanname='plpgsql' FROM pg_proc p JOIN pg_language l ON l.oid=p.prolang
    WHERE p.oid=(SELECT oid FROM ot_installed)),'PLpgSQL language');
SELECT ok(OBJ_DESCRIPTION((SELECT oid FROM ot_installed),'pg_proc')=
    'Insert one mapped publication Order Term for resolved accounts; caller owns transaction and lifecycle.',
    'object comment states scope and caller ownership');

SELECT * FROM finish();
ROLLBACK;
