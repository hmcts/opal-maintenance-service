-- Create opal-maintenance-db and user
CREATE DATABASE "opal-maintenance-db";
CREATE USER "opal-maintenance" WITH ENCRYPTED PASSWORD 'opal-maintenance';
GRANT ALL PRIVILEGES ON DATABASE "opal-maintenance-db" TO "opal-maintenance";
