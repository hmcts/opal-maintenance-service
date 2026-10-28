-- Capture the optional exclusive synthetic dependants before deleting account rows.
CREATE TEMP TABLE publication_owned_contacts ON COMMIT DROP AS
SELECT third_party_contact_id FROM respondent_accounts WHERE business_unit_id=32055 AND third_party_contact_id IS NOT NULL
UNION SELECT third_party_contact_id FROM creditor_accounts WHERE business_unit_id=32055 AND third_party_contact_id IS NOT NULL;
CREATE TEMP TABLE publication_owned_debtors ON COMMIT DROP AS
SELECT debtor_detail_id FROM respondent_accounts WHERE business_unit_id=32055 AND debtor_detail_id IS NOT NULL;
-- Remove only this suite's synthetic publication scope, inside the disposable test database.
CREATE TEMP TABLE publication_owned_parties ON COMMIT DROP AS
SELECT associated_account_id AS party_id FROM respondent_account_parties
WHERE association_type='Respondent' AND respondent_account_id IN
  (SELECT respondent_account_id FROM respondent_accounts WHERE business_unit_id=32055)
UNION SELECT minor_creditor_party_id FROM creditor_accounts WHERE business_unit_id=32055;
DELETE FROM notes WHERE associated_record_type='respondent_accounts' AND associated_record_id IN
  (SELECT respondent_account_id::varchar FROM respondent_accounts WHERE business_unit_id=32055);
DELETE FROM order_terms WHERE respondent_account_id IN
  (SELECT respondent_account_id FROM respondent_accounts WHERE business_unit_id=32055);
DELETE FROM respondent_account_parties WHERE respondent_account_id IN
  (SELECT respondent_account_id FROM respondent_accounts WHERE business_unit_id=32055);
DELETE FROM draft_casefiles WHERE business_unit_id=32055;
DELETE FROM respondent_accounts WHERE business_unit_id=32055;
DELETE FROM creditor_accounts WHERE business_unit_id=32055;
DELETE FROM aliases WHERE party_id IN (SELECT party_id FROM publication_owned_parties);
DELETE FROM parties WHERE party_id IN (SELECT party_id FROM publication_owned_parties);
DELETE FROM third_party_contact WHERE third_party_contact_id IN (SELECT third_party_contact_id FROM publication_owned_contacts);
DELETE FROM debtor_detail WHERE debtor_detail_id IN (SELECT debtor_detail_id FROM publication_owned_debtors);
DELETE FROM account_number_index WHERE business_unit_id=32055;
DELETE FROM major_creditors WHERE business_unit_id=32055;
DELETE FROM business_units WHERE business_unit_id=32055;
DELETE FROM countries WHERE country_id IN (-1065501,-1065502);
DELETE FROM maintenance_applications WHERE application_id=-10655;
DELETE FROM results WHERE result_id IN ('P55A','P55B','P55N');
