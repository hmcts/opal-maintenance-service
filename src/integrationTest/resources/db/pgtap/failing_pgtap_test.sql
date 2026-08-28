BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;

SELECT plan(1);
SELECT fail('deliberate pgTAP failure used to verify the Java runner');
SELECT * FROM finish();

ROLLBACK;
