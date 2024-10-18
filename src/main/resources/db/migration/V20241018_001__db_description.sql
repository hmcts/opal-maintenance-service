/**
*
* CGI OPAL Program
*
* MODULE      : database_comment.sql
*
* DESCRIPTION : Create Initial Migration File 
*
* VERSION HISTORY:
*
* Date          Author      Version     Nature of Change
* ----------    -------     --------    ----------------------------------------------------------------------------
* 18/10/2024    I Readman   1.0         PO-453 Create Maintenance Service Database
*
**/
-- Database build required an inital migration file so adding a description to the database
COMMENT ON DATABASE "opal-maintenance-db" IS 'Opal Maintenance Service Database';

