/**
 * OPAL Program
 *
 * MODULE      : V1_1__foundation.sql
 *
 * DESCRIPTION : Fixed parent-transition regression migration; never production.
 *
 * CHANGE HISTORY:
 *
 * Date        Author         Ticket             Nature of Change
 * ----------  -------------  -----------------  ----------------------------------------
 * 18/10/2026  Frankie Moran  parent-transition  Initial fixed batch regression.
 */
CREATE TABLE public.framework_reference (id INTEGER PRIMARY KEY, original JSON NOT NULL);
INSERT INTO public.framework_reference VALUES (1,'{"duplicate":1, "duplicate":2}');
CREATE SEQUENCE public.framework_sequence;
CREATE TYPE public.framework_enum AS ENUM ('one','two');
CREATE FUNCTION public.framework_existing(public.framework_enum) RETURNS INTEGER LANGUAGE SQL AS 'SELECT 1';
CREATE TABLE public.aliases (surname VARCHAR(35) NOT NULL,forenames VARCHAR(35) NOT NULL,organisation_name VARCHAR(35));
CREATE TABLE public.order_terms (id INTEGER PRIMARY KEY);
INSERT INTO public.aliases VALUES ('fixture','fixture',NULL);
INSERT INTO public.order_terms VALUES (1);
CREATE TABLE public.framework_child (id INTEGER PRIMARY KEY, parent_id INTEGER REFERENCES public.framework_reference(id));
INSERT INTO public.framework_child VALUES (1,1);
CREATE FUNCTION public.framework_trigger() RETURNS TRIGGER LANGUAGE plpgsql AS 'BEGIN RETURN NEW; END';
CREATE TRIGGER framework_reference_trigger BEFORE UPDATE ON public.framework_reference
    FOR EACH ROW EXECUTE FUNCTION public.framework_trigger();
CREATE POLICY framework_reference_policy ON public.framework_reference USING (true);
