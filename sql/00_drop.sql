-- =====================================================================
-- ZOO - zmazanie objektov schemy (pre opakovanu instalaciu)
-- =====================================================================
BEGIN
    FOR r IN (SELECT 'TABLE' typ, column_value nazov
              FROM TABLE(sys.odcivarchar2list(
                  'FOTKA', 'KRMENIE', 'VETERINARNY_ZAZNAM', 'UMIESTNENIE', 'KRMIVO',
                  'ZAMESTNANEC', 'VYBEH', 'ZVIERA', 'DRUH'))
              UNION ALL
              SELECT 'SEQUENCE', column_value
              FROM TABLE(sys.odcivarchar2list(
                  'SEQ_FOTKA', 'SEQ_KRMENIE', 'SEQ_VETERINARNY_ZAZNAM', 'SEQ_UMIESTNENIE',
                  'SEQ_KRMIVO', 'SEQ_ZAMESTNANEC', 'SEQ_VYBEH', 'SEQ_ZVIERA', 'SEQ_DRUH'))
              UNION ALL
              SELECT 'TYPE', column_value
              FROM TABLE(sys.odcivarchar2list(
                  'T_LIEKY', 'T_LIEK', 'T_STRAVA', 'T_TAXONOMIA'))) LOOP
        BEGIN
            EXECUTE IMMEDIATE 'DROP ' || r.typ || ' ' || r.nazov
                || CASE r.typ WHEN 'TABLE' THEN ' CASCADE CONSTRAINTS PURGE'
                              WHEN 'TYPE'  THEN ' FORCE' END;
        EXCEPTION WHEN OTHERS THEN
            IF SQLCODE NOT IN (-942, -2289, -4043) THEN RAISE; END IF;   -- objekt neexistuje
        END;
    END LOOP;
END;
/
