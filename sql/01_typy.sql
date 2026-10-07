-- =====================================================================
-- ZOO - informacny system zoologickej zahrady
-- 01_typy.sql : objektove typy a kolekcie
-- =====================================================================

-- ---------------------------------------------------------------------
-- VARRAY: zlozenie potravy druhu
--   Prvky su kody kategorii krmiva (rovnake ako KRMIVO.KATEGORIA):
--   MASO, RYBY, HMYZ, OVOCIE, ZELENINA, SENO, ZRNINY, GRANULE.
-- ---------------------------------------------------------------------
CREATE OR REPLACE TYPE t_strava AS VARRAY(10) OF VARCHAR2(10);
/

-- ---------------------------------------------------------------------
-- NESTED TABLE objektov: lieky predpisane pri veterinarnom zazname
-- (rovnaky vzor ako HISTORIA v modeli Socialna poistovna)
-- ---------------------------------------------------------------------
CREATE OR REPLACE TYPE t_liek AS OBJECT (
    nazov       VARCHAR2(60),
    davka       NUMBER(8,2),
    jednotka    VARCHAR2(10),       -- mg, ml, tbl, ...
    pocet_dni   NUMBER(3)
);
/

CREATE OR REPLACE TYPE t_lieky AS TABLE OF t_liek;
/

-- ---------------------------------------------------------------------
-- Objektovy typ T_TAXONOMIA - vedecke zaradenie druhu
--   - konstruktor z vedeckeho nazvu ('Panthera tigris altaica')
--   - funkcie: vedecky_nazov, skrateny_nazov, pribuznost
--   - MAP metoda pre triedenie podla systematiky
-- ---------------------------------------------------------------------
CREATE OR REPLACE TYPE t_taxonomia AS OBJECT (
    trieda      VARCHAR2(40),       -- Mammalia
    rad         VARCHAR2(40),       -- Carnivora
    celad       VARCHAR2(40),       -- Felidae
    rod         VARCHAR2(40),       -- Panthera
    epiteton    VARCHAR2(60),       -- tigris altaica (druhove meno, prip. s poddruhom)

    CONSTRUCTOR FUNCTION t_taxonomia (
        p_trieda VARCHAR2, p_rad VARCHAR2, p_celad VARCHAR2, p_vedecky_nazov VARCHAR2
    ) RETURN SELF AS RESULT,

    -- 'Panthera tigris altaica'
    MEMBER FUNCTION vedecky_nazov RETURN VARCHAR2,
    -- 'P. tigris altaica'
    MEMBER FUNCTION skrateny_nazov RETURN VARCHAR2,
    -- uroven spolocneho zaradenia: 0 = ina trieda, 1 = trieda, 2 = rad,
    -- 3 = celad, 4 = rod, 5 = rovnaky druh
    MEMBER FUNCTION pribuznost (p_iny t_taxonomia) RETURN NUMBER,

    MAP MEMBER FUNCTION triedenie RETURN VARCHAR2
);
/

CREATE OR REPLACE TYPE BODY t_taxonomia AS

    CONSTRUCTOR FUNCTION t_taxonomia (
        p_trieda VARCHAR2, p_rad VARCHAR2, p_celad VARCHAR2, p_vedecky_nazov VARCHAR2
    ) RETURN SELF AS RESULT IS
        v_nazov VARCHAR2(120) := TRIM(REGEXP_REPLACE(p_vedecky_nazov, '\s+', ' '));
        v_medzera PLS_INTEGER := INSTR(v_nazov, ' ');
    BEGIN
        IF TRIM(p_trieda) IS NULL OR TRIM(p_rad) IS NULL OR TRIM(p_celad) IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001,
                'Trieda, rad aj celad su povinne: ' || p_vedecky_nazov);
        END IF;
        IF v_medzera = 0 THEN
            RAISE_APPLICATION_ERROR(-20002,
                'Vedecky nazov musi obsahovat rod aj druh: ' || p_vedecky_nazov);
        END IF;
        SELF.trieda   := INITCAP(TRIM(p_trieda));
        SELF.rad      := INITCAP(TRIM(p_rad));
        SELF.celad    := INITCAP(TRIM(p_celad));
        SELF.rod      := INITCAP(SUBSTR(v_nazov, 1, v_medzera - 1));
        SELF.epiteton := LOWER(SUBSTR(v_nazov, v_medzera + 1));
        RETURN;
    END;

    MEMBER FUNCTION vedecky_nazov RETURN VARCHAR2 IS
    BEGIN
        RETURN rod || ' ' || epiteton;
    END;

    MEMBER FUNCTION skrateny_nazov RETURN VARCHAR2 IS
    BEGIN
        RETURN SUBSTR(rod, 1, 1) || '. ' || epiteton;
    END;

    -- Porovnava sa zhora nadol. Chybajuca hodnota na ktorejkolvek strane
    -- znamena, ze zhoda na tej urovni nie je dokazana - porovnanie konci.
    -- (Bez IS NULL by "trieda <> p_iny.trieda" pri NULL nebolo pravdive
    -- a funkcia by mohla vratit 5, hoci zhoda nie je znama.)
    MEMBER FUNCTION pribuznost (p_iny t_taxonomia) RETURN NUMBER IS
    BEGIN
        IF p_iny IS NULL THEN RETURN 0; END IF;
        IF trieda IS NULL OR p_iny.trieda IS NULL OR trieda <> p_iny.trieda THEN RETURN 0; END IF;
        IF rad    IS NULL OR p_iny.rad    IS NULL OR rad    <> p_iny.rad    THEN RETURN 1; END IF;
        IF celad  IS NULL OR p_iny.celad  IS NULL OR celad  <> p_iny.celad  THEN RETURN 2; END IF;
        IF rod    IS NULL OR p_iny.rod    IS NULL OR rod    <> p_iny.rod    THEN RETURN 3; END IF;
        IF epiteton IS NULL OR p_iny.epiteton IS NULL OR epiteton <> p_iny.epiteton THEN RETURN 4; END IF;
        RETURN 5;
    END;

    MAP MEMBER FUNCTION triedenie RETURN VARCHAR2 IS
    BEGIN
        RETURN RPAD(NVL(trieda, ' '), 40) || '|' || RPAD(NVL(rad, ' '), 40) || '|'
            || RPAD(NVL(celad, ' '), 40) || '|' || RPAD(NVL(rod, ' '), 40) || '|'
            || NVL(epiteton, ' ');
    END;
END;
/
