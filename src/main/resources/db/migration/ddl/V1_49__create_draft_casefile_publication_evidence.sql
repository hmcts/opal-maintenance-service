/**
 * OPAL Program
 *
 * MODULE      : V1_49__create_draft_casefile_publication_evidence.sql
 *
 * DESCRIPTION : Create the test-only Draft Casefile publication observation journal.
 *
 * CHANGE HISTORY:
 *
 * Date        Author           Ticket        Nature of Change
 * ----------  ---------------  ------------  ----------------------------------------
 * 22/10/2026  Jonathan Duffy    PO-10626      Persist observations and send attempts.
 */

CREATE TABLE public.draft_casefile_test_observations (
    observation_id         UUID         NOT NULL PRIMARY KEY,
    draft_casefile_id      BIGINT       NOT NULL UNIQUE,
    test_run_reference     VARCHAR(20)  NOT NULL,
    registered_at          TIMESTAMPTZ  NOT NULL,
    CONSTRAINT dcto_draft_id_ck CHECK (draft_casefile_id > 0),
    CONSTRAINT dcto_marker_ck CHECK (test_run_reference ~ '^E2E-[0-9a-f]{16}$')
);

-- No draft foreign key: the independent observer must not wait on the publisher's draft lock.
CREATE TABLE public.draft_casefile_test_send_attempts (
    attempt_id             UUID         NOT NULL PRIMARY KEY,
    observation_id         UUID         NOT NULL REFERENCES public.draft_casefile_test_observations
        (observation_id) ON DELETE CASCADE,
    outcome                VARCHAR(16)  NOT NULL,
    started_at             TIMESTAMPTZ  NOT NULL,
    completed_at           TIMESTAMPTZ,
    CONSTRAINT dctsa_outcome_ck CHECK (outcome IN ('STARTED', 'ACKNOWLEDGED', 'UNCERTAIN')),
    CONSTRAINT dctsa_completion_ck CHECK (
        (outcome = 'STARTED' AND completed_at IS NULL)
        OR (outcome IN ('ACKNOWLEDGED', 'UNCERTAIN')
            AND completed_at IS NOT NULL AND completed_at >= started_at)
    )
);

CREATE INDEX dctsa_observation_id_idx
    ON public.draft_casefile_test_send_attempts (observation_id);

COMMENT ON COLUMN public.draft_casefile_test_observations.observation_id     IS 'Application-generated UUID identifying a publication observation';
COMMENT ON COLUMN public.draft_casefile_test_observations.draft_casefile_id  IS 'Unique Draft Casefile identifier observed without a draft foreign key';
COMMENT ON COLUMN public.draft_casefile_test_observations.test_run_reference IS 'Exact synthetic E2E run marker owning the observation';
COMMENT ON COLUMN public.draft_casefile_test_observations.registered_at      IS 'Instant when this observation was registered';

COMMENT ON COLUMN public.draft_casefile_test_send_attempts.attempt_id     IS 'Application-generated UUID identifying one publication send attempt';
COMMENT ON COLUMN public.draft_casefile_test_send_attempts.observation_id IS 'Parent observation; its deletion removes the related send attempts';
COMMENT ON COLUMN public.draft_casefile_test_send_attempts.outcome        IS 'STARTED, ACKNOWLEDGED or UNCERTAIN publication send outcome';
COMMENT ON COLUMN public.draft_casefile_test_send_attempts.started_at     IS 'Instant when the send attempt was recorded before sending';
COMMENT ON COLUMN public.draft_casefile_test_send_attempts.completed_at   IS 'Completion instant for a terminal outcome, absent while STARTED';
