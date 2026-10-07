-- =====================================================================
-- ZOO - zmazanie objektov schemy (pre opakovanu instalaciu)
-- =====================================================================
BEGIN
    FOR r IN (SELECT 'TABLE' typ, column_value nazov
              FROM TABLE(sys.odcivarchar2list(
                  'KRMENIE', 'VETERINARNY_ZAZNAM', 'UMIESTNENIE', 'KRMIVO',
                  'ZAMESTNANEC', 'VYBEH', 'ZVIERA', 'DRUH'))
              UNION ALL
              SELECT 'TYPE', column_value
              FROM TABLE(sys.odcivarchar2list(
                  'T_LIEKY', 'T_LIEK', 'T_STRAVA', 'T_TAXONOMIA'))) LOOP
        BEGIN
            EXECUTE IMMEDIATE 'DROP ' || r.typ || ' ' || r.nazov
                || CASE r.typ WHEN 'TABLE' THEN ' CASCADE CONSTRAINTS PURGE' ELSE ' FORCE' END;
        EXCEPTION WHEN OTHERS THEN
            IF SQLCODE NOT IN (-942, -4043) THEN RAISE; END IF;   -- objekt neexistuje
        END;
    END LOOP;
END;
/
