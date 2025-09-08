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
