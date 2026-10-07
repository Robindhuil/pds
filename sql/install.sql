-- =====================================================================
-- ZOO - instalacia schemy (typy + sekvencie a tabulky)
-- Spustenie (SQL*Plus / SQLcl / SQL Developer F5) z adresara sql/:
--     @install.sql
-- =====================================================================
WHENEVER SQLERROR EXIT FAILURE ROLLBACK
SET ECHO OFF FEEDBACK OFF DEFINE OFF
@@00_drop.sql
@@01_typy.sql
@@02_tabulky.sql
SET FEEDBACK ON
SELECT object_type, COUNT(*) pocet FROM user_objects
WHERE object_type IN ('TABLE', 'TYPE', 'SEQUENCE', 'INDEX') GROUP BY object_type ORDER BY 1;
-- typ, ktory sa nepodarilo skompilovat, je INVALID (WHENEVER SQLERROR ho nezastavi)
SELECT object_name, object_type FROM user_objects WHERE status = 'INVALID';
