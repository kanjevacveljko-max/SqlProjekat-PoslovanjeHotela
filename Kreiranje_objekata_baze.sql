--1. Kreiranje pogleda view_PregledRezervacija koji prikazuje sve rezervacije i sve podatke o njima.

CREATE VIEW dbo.view_PregledRezervacija
AS
SELECT
    r.id_rezervacije, 
    g.id_gosta, g.ime AS ime_gosta, g.prezime AS prezime_gosta, g.telefon AS telefon_gosta, g.email AS email_gosta,
    s.id_sobe, s.broj_sobe, s.sprat, s.tip_kreveta, s.osnovna_cena,
    z.id_zaposlenog, z.ime AS ime_zaposlenog, z.prezime AS prezime_zaposlenog,
    r.datum_prijave, r.datum_odjave, r.broj_nocenja, r.broj_gostiju, r.status, r.datum_kreiranja,
    r.broj_nocenja * s.osnovna_cena AS cena_sobe
FROM dbo.Rezervacije r
JOIN dbo.Gosti g ON g.id_gosta = r.id_gosta
JOIN dbo.Sobe s ON s.id_sobe = r.id_sobe
JOIN dbo.Zaposleni z ON z.id_zaposlenog = r.id_zaposlenog;
GO


--2. Kreiranje pogleda view_SobeNaRapolaganju koji prikazuje sve sobe koje su trenutno na raspolaganju sa
--   podacima o njima

CREATE OR ALTER VIEW dbo.v_SobeNaRaspolaganju
AS

WITH Aktivne AS (
    SELECT r.id_sobe
    FROM dbo.Rezervacije r
    WHERE r.status IN (N'rezervisano', N'prijavljen')
      AND CAST(GETDATE() AS date) >= r.datum_prijave
      AND CAST(GETDATE() AS date) <  r.datum_odjave
    GROUP BY r.id_sobe
)
SELECT 
    s.id_sobe, s.broj_sobe, s.sprat, s.tip_kreveta,
    s.osnovna_cena, s.status
FROM dbo.Sobe s
LEFT JOIN Aktivne a ON a.id_sobe = s.id_sobe
WHERE a.id_sobe IS NULL
      AND (s.status IS NULL OR s.status NOT IN (N'zauzeta', N'van upotrebe'));
GO


-- 3. Kreinran funkije fn_TrenutniTrosakSobe koja nam prikazuje trenutno zaduzenje za sobu ciji smo id
--    prosledili sa uracunatim dodantnim uslugama.


CREATE OR ALTER FUNCTION dbo.fn_TrenutniTrosakSobe
(
    @id_sobe INT
)
RETURNS DECIMAL(18,2)
AS
BEGIN
    DECLARE 
        @id_rezervacije INT,
        @osnovna_cena  DECIMAL(10,2),
        @datum_prijave DATE,
        @datum_odjave  DATE,
        @nocenja_do_danas INT,
        @iznos_soba    DECIMAL(10,2),
        @iznos_usluge  DECIMAL(10,2),
        @rezultat      DECIMAL(10,2);

    SELECT TOP 1
        @id_rezervacije = r.id_rezervacije,
        @osnovna_cena   = s.osnovna_cena,
        @datum_prijave  = r.datum_prijave,
        @datum_odjave   = r.datum_odjave
    FROM dbo.Rezervacije r
    JOIN dbo.Sobe s ON s.id_sobe = r.id_sobe
    WHERE r.id_sobe = @id_sobe
      AND r.status IN (N'rezervisano', N'prijavljen')
      AND CAST(GETDATE() AS DATE) >= r.datum_prijave
      AND CAST(GETDATE() AS DATE) <  r.datum_odjave
    ORDER BY r.datum_prijave DESC;

    IF @id_rezervacije IS NULL
        RETURN NULL;

    SET @nocenja_do_danas = DATEDIFF(DAY, @datum_prijave, CAST(GETDATE() AS DATE));
    IF @nocenja_do_danas < 1 SET @nocenja_do_danas = 1;

    SET @iznos_soba = @osnovna_cena * @nocenja_do_danas;

    SELECT @iznos_usluge = ISNULL(SUM(kolicina * jedinicna_cena), 0)
    FROM dbo.Usluge
    WHERE id_rezervacije = @id_rezervacije
          AND datum_usluge <= CAST(GETDATE() AS DATE);

    SET @rezultat = @iznos_soba + ISNULL(@iznos_usluge, 0);

    RETURN @rezultat;
END
GO
SELECT dbo.fn_TrenutniTrosakSobe(5) AS trosak_do_danas;


--4. Kreiranje inline table-value funkcije fn_RacunRezime koja nam vraca racun po stavkama za rezervaciju ciji smo
--   id prosledili funkciji.


CREATE FUNCTION dbo.fn_RacunRezime
(
    @id_rezervacije INT
)
RETURNS @racun TABLE
(
    id_rezervacije          INT,
    iznos_soba              DECIMAL(18,2),
    iznos_usluga            DECIMAL(18,2),
    ukupno_placeno          DECIMAL(18,2),
    ukupno_zaduzenje        DECIMAL(18,2),
    saldo                   DECIMAL(18,2)
)
AS
BEGIN
    DECLARE
        @cena_noc DECIMAL(18,2),
        @br_noc   INT,
        @soba     DECIMAL(18,2),
        @usluge   DECIMAL(18,2),
        @placeno  DECIMAL(18,2);

    SELECT 
        @cena_noc = s.osnovna_cena,
        @br_noc   = r.broj_nocenja
    FROM dbo.Rezervacije r
    JOIN dbo.Sobe s ON s.id_sobe = r.id_sobe
    WHERE r.id_rezervacije = @id_rezervacije;

    SET @soba = @cena_noc * @br_noc;

    SELECT @usluge = ISNULL(SUM(kolicina * jedinicna_cena), 0)
    FROM dbo.Usluge
    WHERE id_rezervacije = @id_rezervacije;

    SELECT @placeno = ISNULL(SUM(iznos), 0)
    FROM dbo.Placanja
    WHERE id_rezervacije = @id_rezervacije;

    INSERT INTO @racun
    VALUES
    (
        @id_rezervacije,
        @soba,
        @usluge,
        @placeno,
        @soba + @usluge,
        (@soba + @usluge) - @placeno
    );

    RETURN;
END
GO

SELECT * FROM dbo.fn_RacunRezime(5);


-- 5. Kreiranje multistatement table-value funkcije koja vraca sve prethodne rezervacije gosta ciji
--    id_prosledimo.

CREATE FUNCTION dbo.fn_RezervacijeZaGosta
(
    @id_gosta INT
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        r.id_rezervacije, r.id_gosta, g.ime AS ime_gosta, g.prezime AS prezime_gosta,
        r.id_sobe, s.broj_sobe, r.datum_prijave, r.datum_odjave, r.broj_nocenja,
        r.broj_gostiju, r.status
    FROM dbo.Rezervacije r
    JOIN dbo.Gosti g ON g.id_gosta = r.id_gosta
    JOIN dbo.Sobe  s ON s.id_sobe  = r.id_sobe
    WHERE r.id_gosta = @id_gosta
);
GO

-- 6. 