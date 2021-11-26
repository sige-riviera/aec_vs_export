#!/bin/bash

#set -e

VERBOSE=yes

[[ $VERBOSE =~ yes ]] && VERBOSE_CMD=--verbose
[[ $VERBOSE =~ no ]] && export PGOPTIONS='--client-min-messages=warning'

# NOTE: it is not possible to dump individual table or views without getting problems during restore due to schema definition (rules, triggers, constraints, functions, sequences, relations, etc.).
# Hence we export either: 
# - all qwat database
# - cartoriviera schema which contains only simple data.
# - specific usr_sige schema adapted with needed data
#... or dump a created on the fly schema/table within a select query...

# Drop temporary export schema in qwat database if exits
psql -U sige -d qwat_prod -c 'DROP TABLE IF EXISTS aec_vs_export.vw_export_pipe'
psql -U sige -d qwat_prod -c 'DROP TABLE IF EXISTS aec_vs_export.vw_export_installation'
psql -U sige -d qwat_prod -c 'DROP SCHEMA IF EXISTS aec_vs_export'

# Create temporary export schema in qwat database
psql -U sige -d qwat_prod -c 'CREATE SCHEMA aec_vs_export AUTHORIZATION sige'

# Copy export tables in temporary export schema in qwat database
psql -U sige -d qwat_prod -c 'CREATE TABLE aec_vs_export.vw_export_pipe AS SELECT * FROM qwat_od.vw_export_pipe'
psql -U sige -d qwat_prod -c 'CREATE TABLE aec_vs_export.vw_export_installation AS SELECT * FROM qwat_od.vw_export_installation'

# Do some necessary cast conversion of reglass data types to avoid errors during restore
psql -U sige -d qwat_prod -c 'ALTER TABLE aec_vs_export.vw_export_installation ALTER COLUMN _pipe_node_type type text'
psql -U sige -d qwat_prod -c 'ALTER TABLE aec_vs_export.vw_export_installation ALTER COLUMN installation_type type text'
psql -U sige -d qwat_prod -c 'ALTER TABLE aec_vs_export.vw_export_pipe ALTER COLUMN node_a__pipe_node_type type text'
psql -U sige -d qwat_prod -c 'ALTER TABLE aec_vs_export.vw_export_pipe ALTER COLUMN node_b__pipe_node_type type text'

rm ./qwat_data_export.backup

# Dump export schema
/usr/bin/pg_dump --host localhost --port 5432 --username "sige" --no-password --table "aec_vs_export.vw_export_pipe" --table "aec_vs_export.vw_export_installation" --format custom $VERBOSE_CMD --file "./qwat_data_export.backup" "qwat_prod"
/usr/bin/pg_dump --host localhost --port 5432 --username "sige" --no-password --schema "aec_vs_export" --format custom $VERBOSE_CMD --file "./qwat_data_export.backup" "qwat_prod"

# Drop temporary export schema in qwat database
psql -U sige -d qwat_prod -c 'DROP TABLE aec_vs_export.vw_export_pipe'
psql -U sige -d qwat_prod -c 'DROP TABLE aec_vs_export.vw_export_installation'
psql -U sige -d qwat_prod -c 'DROP SCHEMA aec_vs_export'

# Create export schema in destination database
psql -U sige -d interlis_test -c 'CREATE SCHEMA IF NOT EXISTS aec_vs_export AUTHORIZATION SIGE'

# Restore export schema in destination database
/usr/bin/pg_restore --host localhost --port 5432 --username "sige" --dbname "interlis_test" --schema "aec_vs_export" --no-password $VERBOSE_CMD "./qwat_data_export.backup"

