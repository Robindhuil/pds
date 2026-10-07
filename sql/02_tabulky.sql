-- =====================================================================
-- ZOO - informacny system zoologickej zahrady
-- 02_tabulky.sql : sekvencie, tabulky, integritne obmedzenia, indexy, komentare
--
-- 9 tabuliek: 6 hlavnych (druh, zviera, umiestnenie, krmenie,
-- veterinarny_zaznam, fotka) a 3 mensie (vybeh, zamestnanec, krmivo).
--
-- Kompatibilne s Oracle 19c+ (JSON ulozeny v CLOB s IS JSON,
-- binarne data v SECUREFILE BLOB).
--
-- Vsetky casove intervaly su polootvorene <od, do): den "do" uz do
-- intervalu nepatri a NULL v "do" znamena, ze interval stale trva.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Sekvencie pre primarne kluce (pouzite ako DEFAULT stlpca)
-- ---------------------------------------------------------------------
CREATE SEQUENCE seq_druh               START WITH 1 INCREMENT BY 1 NOCYCLE;
CREATE SEQUENCE seq_zviera             START WITH 1 INCREMENT BY 1 NOCYCLE;
CREATE SEQUENCE seq_vybeh              START WITH 1 INCREMENT BY 1 NOCYCLE;
CREATE SEQUENCE seq_umiestnenie        START WITH 1 INCREMENT BY 1 NOCYCLE;
CREATE SEQUENCE seq_zamestnanec        START WITH 1 INCREMENT BY 1 NOCYCLE;
CREATE SEQUENCE seq_krmivo             START WITH 1 INCREMENT BY 1 NOCYCLE;
CREATE SEQUENCE seq_krmenie            START WITH 1 INCREMENT BY 1 NOCYCLE CACHE 1000;
CREATE SEQUENCE seq_veterinarny_zaznam START WITH 1 INCREMENT BY 1 NOCYCLE;
CREATE SEQUENCE seq_fotka              START WITH 1 INCREMENT BY 1 NOCYCLE;

-- ---------------------------------------------------------------------
-- DRUH - zivocisny druh chovany v ZOO
-- ---------------------------------------------------------------------
CREATE TABLE druh (
    id_druhu          NUMBER        DEFAULT seq_druh.NEXTVAL,
    nazov             VARCHAR2(60)  NOT NULL,
    taxonomia         t_taxonomia   NOT NULL,
    stav_ohrozenia    CHAR(2)       NOT NULL,
    strava            t_strava,
    dlzka_zivota      NUMBER(3),                -- priemerna dlzka zivota v rokoch
    CONSTRAINT pk_druh PRIMARY KEY (id_druhu),
    CONSTRAINT uk_druh_nazov UNIQUE (nazov),
    -- ten isty vedecky nazov nemozu mat dva druhy
    CONSTRAINT uk_druh_vedecky_nazov UNIQUE (taxonomia.rod, taxonomia.epiteton),
    CONSTRAINT ch_druh_taxonomia CHECK (taxonomia.trieda IS NOT NULL
                                    AND taxonomia.rad IS NOT NULL
                                    AND taxonomia.celad IS NOT NULL
                                    AND taxonomia.rod IS NOT NULL
                                    AND taxonomia.epiteton IS NOT NULL),
    CONSTRAINT ch_druh_ohrozenie CHECK (stav_ohrozenia IN ('LC', 'NT', 'VU', 'EN', 'CR', 'EW', 'DD')),
    CONSTRAINT ch_druh_dlzka_zivota CHECK (dlzka_zivota > 0)
);

COMMENT ON TABLE  druh IS 'Zivocisny druh chovany v ZOO';
COMMENT ON COLUMN druh.nazov IS 'Slovensky nazov druhu';
COMMENT ON COLUMN druh.taxonomia IS 'Vedecke zaradenie (objekt T_TAXONOMIA)';
COMMENT ON COLUMN druh.stav_ohrozenia IS 'Kategoria IUCN: LC, NT, VU, EN, CR, EW, DD';
COMMENT ON COLUMN druh.strava IS 'Kategorie krmiva, ktore druh zerie (VARRAY T_STRAVA, kody ako KRMIVO.KATEGORIA)';
COMMENT ON COLUMN druh.dlzka_zivota IS 'Priemerna dlzka zivota v ludskej starostlivosti (roky)';

-- ---------------------------------------------------------------------
-- ZVIERA - konkretny jedinec; rodokmen cez odkaz na matku a otca
--   Eviduju sa len druhy chovane a sledovane po jedincoch (cicavce,
--   vtaky, plazy, vacsie ryby). Hejna drobnych ryb a hmyz sa neeviduju.
-- ---------------------------------------------------------------------
CREATE TABLE zviera (
    id_zvierata       NUMBER        DEFAULT seq_zviera.NEXTVAL,
    id_druhu          NUMBER        NOT NULL,
    meno              VARCHAR2(40)  NOT NULL,
    pohlavie          CHAR(1)       NOT NULL,
    datum_narodenia   DATE,                     -- NULL = nezname (napr. zachrana z prirody)
    datum_prichodu    DATE          NOT NULL,
    sposob_prichodu   VARCHAR2(10)  NOT NULL,
    datum_odchodu     DATE,
    dovod_odchodu     VARCHAR2(10),
    id_matky          NUMBER,
    id_otca           NUMBER,
    CONSTRAINT pk_zviera PRIMARY KEY (id_zvierata),
    CONSTRAINT fk_zviera_druh FOREIGN KEY (id_druhu) REFERENCES druh,
    CONSTRAINT fk_zviera_matka FOREIGN KEY (id_matky) REFERENCES zviera,
    CONSTRAINT fk_zviera_otec FOREIGN KEY (id_otca) REFERENCES zviera,
    CONSTRAINT ch_zviera_pohlavie CHECK (pohlavie IN ('M', 'F')),
    CONSTRAINT ch_zviera_prichod CHECK (sposob_prichodu IN ('NARODENIE', 'PRESUN', 'ZACHRANA')),
    CONSTRAINT ch_zviera_odchod CHECK (dovod_odchodu IN ('UHYN', 'PRESUN', 'VYPUSTENIE')),
    CONSTRAINT ch_zviera_odchod_par CHECK ((datum_odchodu IS NULL AND dovod_odchodu IS NULL)
                                        OR (datum_odchodu IS NOT NULL AND dovod_odchodu IS NOT NULL)),
    -- pri NULL je podmienka UNKNOWN a CHECK ju pusti - nezname datumy nevadia
    CONSTRAINT ch_zviera_datumy CHECK (datum_prichodu >= datum_narodenia
                                       AND datum_odchodu >= datum_prichodu),
    -- zviera narodene v ZOO ma zname narodenie a prislo v ten isty den
    CONSTRAINT ch_zviera_narodenie CHECK (sposob_prichodu <> 'NARODENIE'
                                          OR (datum_narodenia IS NOT NULL
                                              AND datum_prichodu = datum_narodenia)),
    CONSTRAINT ch_zviera_rodicia CHECK (id_matky <> id_zvierata AND id_otca <> id_zvierata)
);

CREATE INDEX ix_zviera_druh  ON zviera (id_druhu);
CREATE INDEX ix_zviera_matka ON zviera (id_matky);
CREATE INDEX ix_zviera_otec  ON zviera (id_otca);

COMMENT ON TABLE  zviera IS 'Konkretny jedinec chovany v ZOO (aj historicky); pobyt v ZOO je interval <datum_prichodu, datum_odchodu)';
COMMENT ON COLUMN zviera.sposob_prichodu IS 'NARODENIE v ZOO, PRESUN z inej ZOO, ZACHRANA z volnej prirody';
COMMENT ON COLUMN zviera.dovod_odchodu IS 'UHYN, PRESUN do inej ZOO, VYPUSTENIE do prirody; NULL = stale v ZOO';
COMMENT ON COLUMN zviera.id_matky IS 'Matka (ak je evidovana v ZOO) - rodokmen';
COMMENT ON COLUMN zviera.id_otca IS 'Otec (ak je evidovany v ZOO) - rodokmen';

-- ---------------------------------------------------------------------
-- VYBEH - vybeh / expozicia
-- ---------------------------------------------------------------------
CREATE TABLE vybeh (
    id_vybehu         NUMBER        DEFAULT seq_vybeh.NEXTVAL,
    nazov             VARCHAR2(60)  NOT NULL,
    zona              VARCHAR2(10)  NOT NULL,
    typ               VARCHAR2(10)  NOT NULL,
    kapacita          NUMBER(4)     NOT NULL,
    rozloha_m2        NUMBER(8,1)   NOT NULL,
    CONSTRAINT pk_vybeh PRIMARY KEY (id_vybehu),
    CONSTRAINT uk_vybeh_nazov UNIQUE (nazov),
    CONSTRAINT ch_vybeh_zona CHECK (zona IN ('AFRIKA', 'AZIA', 'EUROPA', 'AMERIKA', 'AUSTRALIA')),
    CONSTRAINT ch_vybeh_typ CHECK (typ IN ('VONKAJSI', 'VNUTORNY', 'VOLIERA', 'AKVARIUM', 'TERARIUM')),
    CONSTRAINT ch_vybeh_kapacita CHECK (kapacita > 0),
    CONSTRAINT ch_vybeh_rozloha CHECK (rozloha_m2 > 0)
);

COMMENT ON TABLE  vybeh IS 'Vybeh alebo expozicia, v ktorej su umiestnene zvierata';
COMMENT ON COLUMN vybeh.zona IS 'Zoogeograficka zona arealu ZOO: AFRIKA, AZIA, EUROPA, AMERIKA, AUSTRALIA';
COMMENT ON COLUMN vybeh.kapacita IS 'Maximalny pocet zvierat naraz';

-- ---------------------------------------------------------------------
-- UMIESTNENIE - historia: ktore zviera bolo v ktorom vybehu od-do
-- ---------------------------------------------------------------------
CREATE TABLE umiestnenie (
    id_umiestnenia    NUMBER        DEFAULT seq_umiestnenie.NEXTVAL,
    id_zvierata       NUMBER        NOT NULL,
    id_vybehu         NUMBER        NOT NULL,
    datum_od          DATE          NOT NULL,
    datum_do          DATE,                     -- NULL = aktualne umiestnenie
    CONSTRAINT pk_umiestnenie PRIMARY KEY (id_umiestnenia),
    CONSTRAINT fk_umiestnenie_zviera FOREIGN KEY (id_zvierata) REFERENCES zviera,
    CONSTRAINT fk_umiestnenie_vybeh FOREIGN KEY (id_vybehu) REFERENCES vybeh,
    CONSTRAINT ch_umiestnenie_datumy CHECK (datum_do IS NULL OR datum_do > datum_od)
);

CREATE INDEX ix_umiestnenie_zviera ON umiestnenie (id_zvierata, datum_od);
CREATE INDEX ix_umiestnenie_vybeh  ON umiestnenie (id_vybehu, datum_od);

COMMENT ON TABLE  umiestnenie IS 'Casova historia umiestnenia zvierat vo vybehoch (interval <datum_od, datum_do))';
COMMENT ON COLUMN umiestnenie.datum_do IS 'Koniec umiestnenia (exkluzivne); NULL = zviera je vo vybehu teraz';

-- ---------------------------------------------------------------------
-- ZAMESTNANEC - osetrovatel alebo veterinar
-- ---------------------------------------------------------------------
CREATE TABLE zamestnanec (
    id_zamestnanca    NUMBER        DEFAULT seq_zamestnanec.NEXTVAL,
    meno              VARCHAR2(40)  NOT NULL,
    priezvisko        VARCHAR2(40)  NOT NULL,
    pozicia           VARCHAR2(12)  NOT NULL,
    email             VARCHAR2(100) NOT NULL,
    datum_nastupu     DATE          NOT NULL,
    datum_odchodu     DATE,
    CONSTRAINT pk_zamestnanec PRIMARY KEY (id_zamestnanca),
    CONSTRAINT uk_zamestnanec_email UNIQUE (email),
    CONSTRAINT ch_zamestnanec_pozicia CHECK (pozicia IN ('OSETROVATEL', 'VETERINAR')),
    CONSTRAINT ch_zamestnanec_datumy CHECK (datum_odchodu IS NULL OR datum_odchodu > datum_nastupu)
);

COMMENT ON TABLE  zamestnanec IS 'Zamestnanci ZOO - osetrovatelia (krmenie) a veterinari (veterinarne zaznamy)';
COMMENT ON COLUMN zamestnanec.datum_odchodu IS 'Prvy den, ked uz nepracuje (interval <datum_nastupu, datum_odchodu)); NULL = pracuje';

-- ---------------------------------------------------------------------
-- KRMIVO - druh krmiva a jeho cena
-- ---------------------------------------------------------------------
CREATE TABLE krmivo (
    id_krmiva         NUMBER        DEFAULT seq_krmivo.NEXTVAL,
    nazov             VARCHAR2(60)  NOT NULL,
    kategoria         VARCHAR2(10)  NOT NULL,
    cena_za_kg        NUMBER(8,2)   NOT NULL,
    CONSTRAINT pk_krmivo PRIMARY KEY (id_krmiva),
    CONSTRAINT uk_krmivo_nazov UNIQUE (nazov),
    -- rovnake kody pouziva DRUH.STRAVA
    CONSTRAINT ch_krmivo_kategoria CHECK (kategoria IN ('MASO', 'RYBY', 'HMYZ', 'OVOCIE',
                                                        'ZELENINA', 'SENO', 'ZRNINY', 'GRANULE')),
    CONSTRAINT ch_krmivo_cena CHECK (cena_za_kg > 0)
);

COMMENT ON TABLE krmivo IS 'Druhy krmiva a ich nakupna cena';

-- ---------------------------------------------------------------------
-- KRMENIE - jednotlive krmenia zvierat (najobjemnejsia tabulka)
-- ---------------------------------------------------------------------
CREATE TABLE krmenie (
    id_krmenia        NUMBER        DEFAULT seq_krmenie.NEXTVAL,
    id_zvierata       NUMBER        NOT NULL,
    id_krmiva         NUMBER        NOT NULL,
    id_zamestnanca    NUMBER        NOT NULL,
    cas               TIMESTAMP     NOT NULL,
    mnozstvo_kg       NUMBER(7,3)   NOT NULL,
    poznamka          VARCHAR2(200),
    CONSTRAINT pk_krmenie PRIMARY KEY (id_krmenia),
    CONSTRAINT fk_krmenie_zviera FOREIGN KEY (id_zvierata) REFERENCES zviera,
    CONSTRAINT fk_krmenie_krmivo FOREIGN KEY (id_krmiva) REFERENCES krmivo,
    CONSTRAINT fk_krmenie_zamestnanec FOREIGN KEY (id_zamestnanca) REFERENCES zamestnanec,
    CONSTRAINT ch_krmenie_mnozstvo CHECK (mnozstvo_kg > 0)
);

CREATE INDEX ix_krmenie_zviera      ON krmenie (id_zvierata);
CREATE INDEX ix_krmenie_krmivo      ON krmenie (id_krmiva);
CREATE INDEX ix_krmenie_zamestnanec ON krmenie (id_zamestnanca);

COMMENT ON TABLE  krmenie IS 'Zaznam o kazdom krmeni zvierata';
COMMENT ON COLUMN krmenie.id_zamestnanca IS 'Osetrovatel, ktory krmil';
COMMENT ON COLUMN krmenie.poznamka IS 'Napr. nezjedol, zjedol polovicu';

-- ---------------------------------------------------------------------
-- VETERINARNY_ZAZNAM - prehliadky, ockovania, liecby, zakroky
-- ---------------------------------------------------------------------
CREATE TABLE veterinarny_zaznam (
    id_zaznamu        NUMBER        DEFAULT seq_veterinarny_zaznam.NEXTVAL,
    id_zvierata       NUMBER        NOT NULL,
    id_zamestnanca    NUMBER        NOT NULL,
    cas               TIMESTAMP     NOT NULL,
    typ               VARCHAR2(10)  NOT NULL,
    diagnoza          VARCHAR2(200),
    popis             VARCHAR2(2000),
    lieky             t_lieky,
    vysledky          CLOB,                     -- JSON: krvny obraz, vaha, teplota, ...
    nalez             BLOB,                     -- PDF sprava / rontgen
    nalez_nazov       VARCHAR2(200),
    nalez_mime        VARCHAR2(50),
    CONSTRAINT pk_veterinarny_zaznam PRIMARY KEY (id_zaznamu),
    CONSTRAINT fk_vet_zviera FOREIGN KEY (id_zvierata) REFERENCES zviera,
    CONSTRAINT fk_vet_zamestnanec FOREIGN KEY (id_zamestnanca) REFERENCES zamestnanec,
    CONSTRAINT ch_vet_typ CHECK (typ IN ('PREHLIADKA', 'OCKOVANIE', 'LIECBA', 'ZAKROK')),
    CONSTRAINT ch_vet_vysledky CHECK (vysledky IS JSON),
    CONSTRAINT ch_vet_nalez CHECK (nalez IS NULL OR (nalez_nazov IS NOT NULL AND nalez_mime IS NOT NULL))
)
NESTED TABLE lieky STORE AS veterinarny_zaznam_lieky_nt
LOB (vysledky) STORE AS SECUREFILE
LOB (nalez) STORE AS SECUREFILE;

CREATE INDEX ix_vet_zviera      ON veterinarny_zaznam (id_zvierata);
CREATE INDEX ix_vet_zamestnanec ON veterinarny_zaznam (id_zamestnanca);

COMMENT ON TABLE  veterinarny_zaznam IS 'Veterinarne zaznamy zvierat';
COMMENT ON COLUMN veterinarny_zaznam.id_zamestnanca IS 'Veterinar, ktory zaznam vytvoril';
COMMENT ON COLUMN veterinarny_zaznam.lieky IS 'Predpisane lieky (NESTED TABLE T_LIEKY)';
COMMENT ON COLUMN veterinarny_zaznam.vysledky IS 'Namerane hodnoty v JSON (vaha, teplota, krvny obraz)';
COMMENT ON COLUMN veterinarny_zaznam.nalez IS 'Priloha - PDF sprava alebo rontgenova snimka';

-- ---------------------------------------------------------------------
-- FOTKA - fotografie zvierat ulozene priamo v DB (sprava suborov)
-- ---------------------------------------------------------------------
CREATE TABLE fotka (
    id_fotky          NUMBER        DEFAULT seq_fotka.NEXTVAL,
    id_zvierata       NUMBER        NOT NULL,
    nazov_suboru      VARCHAR2(200) NOT NULL,
    mime_typ          VARCHAR2(50)  NOT NULL,
    obsah             BLOB          NOT NULL,   -- pri vkladani EMPTY_BLOB(), potom DBMS_LOB
    popis             VARCHAR2(500),
    datum_nahratia    DATE          DEFAULT SYSDATE NOT NULL,
    hlavna            CHAR(1)       DEFAULT 'N' NOT NULL,
    CONSTRAINT pk_fotka PRIMARY KEY (id_fotky),
    CONSTRAINT fk_fotka_zviera FOREIGN KEY (id_zvierata) REFERENCES zviera ON DELETE CASCADE,
    CONSTRAINT ch_fotka_mime CHECK (mime_typ LIKE 'image/%'),
    CONSTRAINT ch_fotka_hlavna CHECK (hlavna IN ('A', 'N'))
)
LOB (obsah) STORE AS SECUREFILE;

CREATE INDEX ix_fotka_zviera ON fotka (id_zvierata);
-- funkcny index: kazde zviera ma najviac jednu hlavnu (profilovu) fotku
CREATE UNIQUE INDEX ux_fotka_hlavna ON fotka (CASE WHEN hlavna = 'A' THEN id_zvierata END);

COMMENT ON TABLE  fotka IS 'Fotografie zvierat ulozene v databaze';
COMMENT ON COLUMN fotka.obsah IS 'Obsah suboru (BLOB)';
COMMENT ON COLUMN fotka.hlavna IS 'A = profilova fotka zvierata (najviac jedna na zviera)';
