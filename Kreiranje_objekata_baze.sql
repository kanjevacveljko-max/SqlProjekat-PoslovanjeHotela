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



