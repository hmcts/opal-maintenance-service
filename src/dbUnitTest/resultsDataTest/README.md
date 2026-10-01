# Results reference data

## Delivery contract

PO-10893 and PO-10894 are delivered together, in this order:

1. The immutable original `data/allEnvs/V1_13__insert_results_reference_data.sql` supplies the 22 keys.
2. `ddl/V1_15__allow_null_results_permitted_actions.sql` drops only NOT NULL from `public.results.enf_next_permitted_actions`. VARCHAR(100), stored values and other schema properties remain unchanged.
3. `data/allEnvs/V1_16__refresh_results_reference_data.sql` uses 22 plain UPDATE statements, changing only `order_term`, `result_parameters` and `enf_next_permitted_actions`.

The refresh preserves all other columns and unrelated rows. Blank permitted actions become SQL NULL. JSON text, types and array order are retained exactly; there is no trimming, reserialization, generated ID, numeric conversion of keys, inferred transformation, insert, delete or upsert. The three formerly true order terms MNSTD, MPAY and MTEMP become false; MWDN retains `[]`.

The approved deployment starts with a clean database and applies the seed and updates together. On 1 October 2026 the ticket owner explicitly removed the earlier missing-key guard and missing-key failure tests from the delivery design. The source ticket's old AC2/AC3 wording has not been republished: this is an approved deviation, not a claim that plain UPDATE raises on zero matches. Exact final-data validation still detects missing expected keys. Reassess the contract if deployment changes to standing data.

## Authority

Specs, relative to the configured RM context workspace:

- `rm/create-case-file/tickets/approved/db/db-rm-results-nullability-po-10893.md`
- `rm/create-case-file/tickets/approved/db/db-rm-results-reference-data-refresh-po-10894.md`

The accepted design revision is `d9e54b334ce89143ae93bf88420a40cd1e6c72d6` in [the context merge request](https://gitlab.clouddev.online/opal-rm/opal-rm-agent-context/-/merge_requests/130). TDIA and workbook permit NULL and the entity's NOT NULL wording was removed. The ticket owner confirmed LLD completion; no further design publication is part of this delivery.

Current independent fixture: `rm/common/reference-data/results.csv`, source revision `814003f9e65ae5416953d2a0fb07a1bef2315b5e`, SHA-256 `4e1cd867f87ebbe8476fbc51ab224add195cf2d5b71640605202d6ee8a552fce`. The retained `results.csv` is byte-identical: 22 unique keys, 20 columns and 86 parameters. It is copied from that input, never generated from the migration. Production SQL contains literals and does not read the fixture.

The original seed's input fingerprint was `72537e13e31cb59dc93f54353308e33587207180ee409e325834d3e8d8486993`. That history remains immutable; the single current fixture describes the refreshed state and must not be used as an expectation for the original seed's old values.

Execution base: Maintenance master `5a6ce62aa02c9fcbd4c1908fd93d6fce55197376`. Versions were allocated after checking the complete migration tree and live target. Check the target again before integration.

## Maintained tests

Run `./gradlew --no-daemon dbUnitTest` with Java 21 and Docker. The existing Gradle runner starts disposable PostgreSQL 17, applies `ddl`, `data/allEnvs` and `data/dev`, validates Flyway, proves repeat migration is a no-op, runs the suites and removes the container.

- `../resultsTest/results_pgtap_tests.sql`: 93 schema and behaviour assertions, including NULL insert/update, retained VARCHAR(100), 100-character acceptance and 101-character rejection.
- `results_data_pgtap_tests.sql`: 11 assertions covering independent source keys/count, 86 parameters, all 20 final fields with exact JSON text, SQL NULL, non-target/unrelated-row preservation, replay, late constraint-failure rollback, three historical seed duplicate-key cases and fixture restoration.

Tests use rollback-only transactions. The refresh failure test deliberately rejects the last UPDATE after earlier updates changed a synthetic value, and verifies complete restoration. Only test-local helpers catch exceptions; production exceptions propagate to Flyway. Historical duplicate checks invoke the unchanged original seed, not the refresh. Synthetic keys are test-owned; no environment-derived records are used.

These are the two maintained Results suites and one current CSV. Future data changes update this fixture and the applicable assertions. No permanent suite or fixture is added per refresh. Normal dbUnitTest checks the final state after all migrations; it does not prove intermediate predecessor behavior.

## Disposable predecessor validation

For this delivery, use the following one-off runbook from the repository root. It applies the actual predecessor through 1.14, records all original values plus one unrelated synthetic row, applies 1.15, verifies preservation before 1.16, then verifies refreshed data, unchanged columns/rows, Flyway validation and repeat/no-op behavior. This controlled verification is separate from the clean-database deployment assumption.

Requirements: Python 3, Docker, repository pgTAP Dockerfile and pinned Flyway image. No shared connection settings may be present. The script publishes no host port and mounts no persistent database volume. It removes its exact container and temporary stage SQL even on failure. The current runner stops explicitly at 1.16; future migrations must not silently change this checkpoint. Update this current runbook when a later ticket changes the expected dataset.

Save the following Python block to a newly created temporary file outside the repository, then use the capture commands below. Do not keep a permanent runner or stage files in the test tree.

```python
import os, pathlib, re, shutil, subprocess, tempfile, time, uuid
repo=pathlib.Path.cwd()
versions=[os.environ[k] for k in ('RESULTS_PREDECESSOR','RESULTS_SCHEMA_VERSION','RESULTS_DATA_VERSION')]
assert all(re.fullmatch(r'1\.[0-9]+',v) for v in versions)
assert int(versions[0].split('.')[1]) < int(versions[1].split('.')[1]) < int(versions[2].split('.')[1])
for k in os.environ:
    if (k.startswith('FLYWAY_') or k.startswith('OPAL_MAINTENANCE_DB_')) and os.environ[k].strip():
        raise RuntimeError('Refusing external database setting: '+k)
image=re.search(r"flywayImageName = '([^']+)'",(repo/'gradle/db-unit-test.gradle').read_text()).group(1)
name='opal-results-upgrade-'+uuid.uuid4().hex
pgimage='opal-maintenance-db-unit-test-postgres:17'
db='opal_results_upgrade'
stage_dir=pathlib.Path(tempfile.mkdtemp(prefix="opal-results-stages-",dir="/private/tmp"))
stage_dir.joinpath('setup.sql').write_text('-- Scenario: establish the real predecessor and unrelated synthetic row.\n-- Setup: predecessor Flyway chain completed in a new disposable database.\n-- Expected: snapshots survive S unchanged and retain all non-target values after D.\nCREATE SCHEMA results_upgrade_probe;\nCREATE VIEW results_upgrade_probe.row_values AS\nSELECT r.result_id::text AS result_id,\n       row_to_json(v)::text AS exact_value,\n       to_jsonb(v)-\'order_term\'-\'result_parameters\'-\'enf_next_permitted_actions\' AS unchanged_columns\nFROM public.results r\nCROSS JOIN LATERAL (\n SELECT r.result_id, r.result_title, r.order_term,r.enforcement_result,r.case_result,\n r.case_result_type,r.active,r.order_accruing,r.requires_creditor,r.enforcement_hold,\n r.requires_enforcer,r.generates_hearing,r.generates_warrant,r.lists_monies,\n r.result_parameters::text AS result_parameters,r.requires_employment_data,\n r.allow_additional_action,r.enf_next_permitted_actions,r.manual_enforcement,r.auto_enforcement\n) v;\nINSERT INTO public.results VALUES\n (\'T94002\',\'Upgrade synthetic Result\',false,false,true,\'Ancillary\',\n  false,false,false,false,false,false,false,false,\'{ "z": 1 }\'::json,\n  false,false,\'Preserve me\',false,false);\nCREATE TABLE results_upgrade_probe.before_rows AS\nSELECT * FROM results_upgrade_probe.row_values;\nCREATE TABLE results_upgrade_probe.before_schema AS\nSELECT column_name,data_type,character_maximum_length,column_default,is_nullable\nFROM information_schema.columns WHERE table_schema=\'public\' AND table_name=\'results\';\n')
stage_dir.joinpath('nullability_checks.sql').write_text("BEGIN;\nCREATE EXTENSION IF NOT EXISTS pgtap;\nSELECT plan(4);\n-- Scenario: schema relaxed before reference values are refreshed.\n-- Setup: actual S applied after predecessor snapshot; D not yet applied.\n-- Expected: nullable VARCHAR(100), all rows unchanged, all other columns unchanged.\nSELECT col_is_null('public','results','enf_next_permitted_actions','upgrade allows NULL');\nSELECT col_type_is('public','results','enf_next_permitted_actions','varchar(100)','upgrade retains width');\nSELECT results_eq(\n 'SELECT * FROM results_upgrade_probe.row_values ORDER BY result_id',\n 'SELECT * FROM results_upgrade_probe.before_rows ORDER BY result_id',\n 'nullability migration preserves every existing value');\nSELECT results_eq(\n $$SELECT column_name::text,data_type::text,character_maximum_length,column_default::text,is_nullable::text\n   FROM information_schema.columns WHERE table_schema='public' AND table_name='results'\n   ORDER BY column_name$$,\n $$SELECT column_name::text,data_type::text,character_maximum_length,column_default::text,\n   CASE WHEN column_name='enf_next_permitted_actions' THEN 'YES' ELSE is_nullable::text END\n   FROM results_upgrade_probe.before_schema ORDER BY column_name$$,\n 'only column nullability changes');\nSELECT * FROM finish();\nROLLBACK;\n")
stage_dir.joinpath('refresh_checks.sql').write_text("BEGIN;\nCREATE EXTENSION IF NOT EXISTS pgtap;\nSELECT plan(3);\n-- Scenario: actual D applies on top of the preserved predecessor data.\n-- Setup: original seeded rows plus unrelated synthetic fixture were upgraded.\n-- Expected: key set and other 17 columns unchanged; unrelated row byte-equivalent.\nSELECT results_eq(\n 'SELECT result_id,unchanged_columns FROM results_upgrade_probe.row_values ORDER BY result_id',\n 'SELECT result_id,unchanged_columns FROM results_upgrade_probe.before_rows ORDER BY result_id',\n 'upgrade preserves keys and every non-target column');\nSELECT results_eq(\n $$SELECT exact_value FROM results_upgrade_probe.row_values WHERE result_id='T94002'$$,\n $$SELECT exact_value FROM results_upgrade_probe.before_rows WHERE result_id='T94002'$$,\n 'unrelated row survives actual Flyway refresh unchanged');\nSELECT is((SELECT enf_next_permitted_actions::text FROM public.results WHERE result_id='T94002'),\n 'Preserve me','unrelated non-null permitted actions survive both migrations');\nSELECT * FROM finish();\nROLLBACK;\n")
started=False
attempted=False
began=time.monotonic()
def run(args,**kw):
    return subprocess.run(args,check=True,text=True,**kw)
def sql(statement):
    return subprocess.check_output(['docker','exec',name,'psql','-X','-v','ON_ERROR_STOP=1',
        '-U','postgres','-d',db,'-At','-c',statement],text=True).strip()
def tap(path):
    run(['docker','exec',name,'pg_prove','--verbose','-h','localhost','-U','postgres','-d',db,path])
try:
    run(['docker','build','-f','docker/postgres-pgtap.Dockerfile','-t',pgimage,'.'])
    attempted=True
    run(['docker','run','--detach','--rm','--name',name,
         '-e','POSTGRES_HOST_AUTH_METHOD=trust','-e','POSTGRES_DB='+db,pgimage])
    started=True
    for attempt in range(60):
        proc=subprocess.run(['docker','exec',name,'cat','/proc/1/comm'],capture_output=True,text=True)
        ready=subprocess.run(['docker','exec',name,'pg_isready','-U','postgres','-d',db],capture_output=True)
        if proc.returncode==0 and proc.stdout.strip()=='postgres' and ready.returncode==0:break
        time.sleep(1)
    else:raise RuntimeError('Disposable PostgreSQL not ready')
    assert sql("SELECT count(*) FROM pg_tables WHERE schemaname='public'")=='0'
    fw=['docker','run','--rm','--network','container:'+name]
    for folder in ('ddl','data/allEnvs','data/dev'):
        path=repo/'src/main/resources/db/migration'/folder
        assert path.is_dir()
        fw+=['-v',str(path)+':/flyway/sql/'+folder+':ro']
    fw += [image,'-url=jdbc:postgresql://localhost:5432/'+db,'-user=postgres',
        '-locations=filesystem:/flyway/sql/ddl,filesystem:/flyway/sql/data/allEnvs,filesystem:/flyway/sql/data/dev',
        '-baselineOnMigrate=false','-cleanDisabled=true']
    print('PostgreSQL image:',pgimage,'Flyway image:',image)
    print('Predecessor, schema, refresh versions:',*versions)
    print('Migration locations: ddl, data/allEnvs, data/dev')
    run(fw+['-target='+versions[0],'migrate'])
    assert sql('SELECT version FROM public.flyway_schema_history WHERE success ORDER BY installed_rank DESC LIMIT 1')==versions[0]
    run(['docker','cp',str(repo/'src/dbUnitTest')+'/.',name+':/tmp/opal-db-unit-test'])
    run(['docker','cp',str(repo/'src/main/resources/db/migration')+'/.',name+':/tmp/opal-db-migrations'])
    run(['docker','cp',str(stage_dir)+'/.',name+':/tmp/results-upgrade-checks'])
    run(['docker','exec',name,'psql','-X','-v','ON_ERROR_STOP=1','-U','postgres','-d',db,
         '-f','/tmp/results-upgrade-checks/setup.sql'])
    run(fw+['-target='+versions[1],'migrate'])
    assert sql('SELECT version FROM public.flyway_schema_history WHERE success ORDER BY installed_rank DESC LIMIT 1')==versions[1]
    tap('/tmp/results-upgrade-checks/nullability_checks.sql')
    tap('/tmp/opal-db-unit-test/resultsTest/results_pgtap_tests.sql')
    run(fw+['-target='+versions[2],'migrate'])
    assert sql('SELECT version FROM public.flyway_schema_history WHERE success ORDER BY installed_rank DESC LIMIT 1')==versions[2]
    run(fw+['validate'])
    tap('/tmp/results-upgrade-checks/refresh_checks.sql')
    tap('/tmp/opal-db-unit-test/resultsDataTest/results_data_pgtap_tests.sql')
    history=sql('SELECT string_agg(row_to_json(h)::text, E\'\\n\' ORDER BY installed_rank) FROM public.flyway_schema_history h')
    run(fw+['-target='+versions[2],'migrate'])
    assert history==sql('SELECT string_agg(row_to_json(h)::text, E\'\\n\' ORDER BY installed_rank) FROM public.flyway_schema_history h')
    print('Upgrade, intermediate preservation, final data, Flyway validate and no-op: PASS')
finally:
    try:
        if attempted:
            names=subprocess.check_output(['docker','ps','-a','--format','{{.Names}}'],text=True).splitlines()
            if name in names:run(['docker','rm','--force',name])
            remaining=subprocess.check_output(['docker','ps','-a','--format','{{.Names}}'],text=True).splitlines()
            assert name not in remaining,'Disposable cleanup not confirmed'
            print('Cleanup confirmed')
        print('Duration seconds:',round(time.monotonic()-began,2))
    finally:
        shutil.rmtree(stage_dir)
        assert not stage_dir.exists()
```

```bash
results_upgrade_runner=$(mktemp /private/tmp/opal-results-upgrade.XXXXXX)
# Save the complete Python block above into this newly created file.
export RESULTS_PREDECESSOR=1.14
export RESULTS_SCHEMA_VERSION=1.15
export RESULTS_DATA_VERSION=1.16
mkdir -p build/reports/resultsUpgrade
python3 "$results_upgrade_runner" > build/reports/resultsUpgrade/run.log 2>&1
results_upgrade_status=$?
rm -- "$results_upgrade_runner"
cat build/reports/resultsUpgrade/run.log
[ "$results_upgrade_status" -eq 0 ]
```

A valid report includes 111 passing assertions (4 intermediate, 93 schema, 3 final preservation and 11 data), the upgrade PASS message and confirmed cleanup. An empty report or command exit alone is insufficient. Raw evidence stays ignored under `build/reports/`; summarize commands/results in the PR. Interrupted runs require checking/removing only the uniquely named container recorded in the log, never broad Docker cleanup.

## Operations and recovery

This schema and reference data apply wherever the `ddl` and `data/allEnvs` locations are selected. No environment-specific rows, privileges, defaults, indexes, comments, enums or sequences are added or changed. The ALTER acquires a table lock and can wait behind active transactions; it does not intentionally rewrite stored values. The refresh locks the 22 matching rows. Exclude concurrent operational writers during migration; disposable timings are not a production downtime guarantee.

Flyway owns each migration transaction. If 1.15 succeeds but 1.16 fails with a SQL error, the schema may remain nullable while the refresh leaves no partial changes. Diagnose the error and validate recovery in a disposable instance. Applied migrations remain immutable: corrections are forward-only. Do not add rows to conceal a final-data mismatch, or run clean/repair/manual history edits as routine recovery.

Post-migration signals: Flyway validate succeeds, no migrations remain pending, all 22 approved keys reconcile exactly, permitted actions are NULL for those keys, and unrelated rows/columns retain their values. Existing startup/health and backend regression tests remain part of the project build. Runtime consumers must be checked before rollout for nullable actions and the revised JSON types/metadata, read-only Frequency, date flags and ChildDOB identifier. This is a rollout obligation, not an implementation blocker or an established consumer defect.

Human SQL peer review, at least two reviewers, QA, CI, merge and deployment need separate evidence. The change introduces no dependencies, CVE suppressions, secrets, PII or persistent routines. Database contract assertions cover fresh and controlled predecessor paths; raw execution reports and PR prose provide the per-ticket AC mapping.
