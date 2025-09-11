--1. Kreiranje pogleda view_PregledRezervacija koji prikazuje sve rezervacije i sve podatke o njima.

create view dbo.view_PregledRezervacija
as
select
    r.id_rezervacije, 
    g.id_gosta, g.ime as ime_gosta, g.prezime as prezime_gosta, g.telefon as telefon_gosta, 
    g.email as email_gosta, s.id_sobe, s.broj_sobe, s.sprat, s.tip_kreveta, s.osnovna_cena,
    z.id_zaposlenog, z.ime as ime_zaposlenog, z.prezime as prezime_zaposlenog,
    r.datum_prijave, r.datum_odjave, r.broj_nocenja, r.broj_gostiju, r.status, r.datum_kreiranja,
    r.broj_nocenja * s.osnovna_cena as cena_sobe
from dbo.Rezervacije r
join dbo.Gosti g on g.id_gosta = r.id_gosta
join dbo.Sobe s on s.id_sobe = r.id_sobe
left join dbo.Zaposleni z on z.id_zaposlenog = r.id_zaposlenog;
go


--2. Kreiranje pogleda view_SobeNaRapolaganju koji prikazuje sve sobe koje su trenutno na raspolaganju sa
--   podacima o njima

create view dbo.view_SobeNaRaspolaganju
as

with Aktivne as (
    select r.id_sobe
    from dbo.Rezervacije r
    where r.status in (N'rezervisano', N'prijavljen')
      and cast(getdate() as date) >= r.datum_prijave
      AND cast(getdate() as date) <  r.datum_odjave
    group by r.id_sobe
)
select 
    s.id_sobe, s.broj_sobe, s.sprat, s.tip_kreveta,
    s.osnovna_cena, s.status
from dbo.Sobe s left join Aktivne a 
     on a.id_sobe = s.id_sobe
where a.id_sobe is null
      and (s.status is null or s.status not in
      (N'zauzeta', N'van upotrebe'));
go


-- 3. Kreinran funkije fn_TrenutniTrosakSobe koja nam prikazuje trenutno zaduzenje za sobu ciji smo id
--    prosledili sa uracunatim dodantnim uslugama.

alter function fn_TrenutniTrosakSobe(@idSobe int)
returns real
as
begin
    declare @danasnji_datum date = cast(getdate() as date),
            @id_rezervacije int,
            @datum_prijave date,
            @datum_odjave date,
            @nocenja_do_danas int,
            @osnovna_cena real,
            @iznos_soba real,
            @iznos_usluge real,
            @rezultat real;

    select top 1
        @id_rezervacije = r.id_rezervacije,
        @datum_prijave = r.datum_prijave,
        @datum_odjave = r.datum_odjave,
        @osnovna_cena = s.osnovna_cena
    from rezervacije r inner join sobe s 
         on r.id_sobe = r.id_sobe
    where r.id_sobe = @idSobe and
          @danasnji_datum > @datum_prijave and
          @danasnji_datum < @datum_odjave and
          r.status in (N'prijavljen', N'rezervisano')
    order by r.datum_prijave desc

    if @id_rezervacije is null
        return null;

    set @nocenja_do_danas = datediff(day, @datum_prijave, @danasnji_datum);
    if @nocenja_do_danas < 1
        set @nocenja_do_danas = 1;

    set @iznos_soba = @nocenja_do_danas * @osnovna_cena;

    select @iznos_usluge = isnull(sum(kolicina * jedinicna_cena), 0)
    from usluge
    where id_rezervacije = @id_rezervacije and
          datum_usluge <= @danasnji_datum;

    set @rezultat = @iznos_soba + isnull(@iznos_usluge, 0);

    return @rezultat;

end
go


--4. Kreiranje inline table-value funkcije fn_RacunRezime koja nam vraca racun po stavkama za rezervaciju ciji smo
--   id prosledili funkciji.

create function fn_RacunRezime(@idRezervacije int)
returns @Rezultat table(
        id_rezervacije int,
        iznos_soba real,
        iznos_usluge real,
        ukupno_zaduzenje real,
        ukupno_placeno real,
        saldo real)
as
begin
    declare @broj_nocenja int,
            @cena_noc real,
            @soba real,
            @usluge real,
            @placeno real;

    select 
        @broj_nocenja = r.broj_nocenja,
        @cena_noc = s.osnovna_cena
    from rezervacije r join sobe s 
         on r.id_sobe = s.id_sobe
    where r.id_rezervacije = @idRezervacije;

    if @cena_noc is null or @broj_nocenja is null 
        return;

    set @soba = @cena_noc * @broj_nocenja;

    select @usluge = isnull(sum(kolicina * jedinicna_cena), 0)
    from usluge
    where id_rezervacije = @idRezervacije;

    select @placeno = isnull(sum(iznos), 0)
    from placanja
    where id_rezervacije = @idRezervacije;

    insert into @Rezultat (id_rezervacije, iznos_soba, iznos_usluge, ukupno_zaduzenje,
                          ukupno_placeno, saldo)
    values (@idRezervacije, @soba, @usluge, @soba+@usluge, @placeno, @soba+@usluge-@placeno);

    return;
end
go

        


-- 5. Kreiranje multistatement table-value funkcije koja vraca sve prethodne rezervacije gosta ciji
--    id prosledimo.

CREATE FUNCTION dbo.fn_RezervacijeZaGosta
(
    @id_gosta INT
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        r.id_rezervacije, r.id_gosta, 
        g.ime AS ime_gosta, g.prezime AS prezime_gosta,
        r.id_sobe, s.broj_sobe, r.datum_prijave, 
        r.datum_odjave, r.broj_nocenja,
        r.broj_gostiju, r.status
    FROM dbo.Rezervacije r
    JOIN dbo.Gosti g ON g.id_gosta = r.id_gosta
    JOIN dbo.Sobe  s ON s.id_sobe  = r.id_sobe
    WHERE r.id_gosta = @id_gosta
);
GO

-- 6. Kreiranje procedure sp_DodajUslugu koja prihvata ulazne parametre i dodaje novu uslugu u tabelu usluge

CREATE PROCEDURE dbo.sp_DodajUslugu
    @id_rezervacije INT,
    @id_zaposlenog  INT = NULL,
    @opis_usluge    NVARCHAR(200),
    @kolicina       INT = 1,
    @jedinicna_cena DECIMAL(10,2),
    @datum_usluge   DATE = NULL
AS

BEGIN

    SET NOCOUNT ON;

    IF @datum_usluge IS NULL
        SET @datum_usluge = CAST(GETDATE() AS DATE);

    IF @kolicina IS NULL OR @kolicina <= 0
    BEGIN
        RAISERROR (N'Koli?ina mora biti ve?a od nule.', 11, 1);
        RETURN;
    END;

    IF @jedinicna_cena IS NULL OR @jedinicna_cena < 0
    BEGIN
        RAISERROR (N'Jedini?na cena ne može biti negativna.', 11, 1);
        RETURN;
    END;

    INSERT INTO dbo.Usluge
        (id_rezervacije, id_zaposlenog, datum_usluge, opis_usluge, kolicina, jedinicna_cena)
    VALUES
        (@id_rezervacije, @id_zaposlenog, @datum_usluge, @opis_usluge, @kolicina, @jedinicna_cena);

END
GO


-- 7. Kreinranje uskladistene procedure sp_PredloziSobu koja na osnovu ulaznih parametara u vidu 
--    datuma prijave i odjave, tipa kreveta i maksimalne cene pronalazi sobu koja je u tom trenutku
--    slobodna i koja se uklapa u kriterijume

CREATE PROCEDURE dbo.sp_PredloziSobu
    @od       DATE,
    @do       DATE,
    @tip_kreveta NVARCHAR(30) = NULL,
    @max_cena   DECIMAL(10,2) = NULL,
    @id_sobe INT OUTPUT,
    @poruka  NVARCHAR(200) OUTPUT
AS
BEGIN

    IF @od IS NULL OR @do IS NULL
    BEGIN
        RAISERROR (N'Parametri @od i @do su obavezni.', 11, 1);
        RETURN;
    END

    IF @do <= @od
    BEGIN
        RAISERROR (N'Datum odjave mora biti strogo ve?i od datuma prijave.', 11, 1);
        RETURN;
    END

    SET @id_sobe = NULL;

    SELECT TOP (1) @id_sobe = s.id_sobe
    FROM dbo.Sobe s
    WHERE (s.status IS NULL OR s.status NOT IN (N'van upotrebe'))
      AND (@tip_kreveta IS NULL OR s.tip_kreveta = @tip_kreveta)
      AND (@max_cena IS NULL OR s.osnovna_cena <= @max_cena)
      AND NOT EXISTS (
            SELECT 1
            FROM dbo.Rezervacije r
            WHERE r.id_sobe = s.id_sobe
              AND r.status IN (N'rezervisano', N'prijavljen')
              AND NOT (@do <= r.datum_prijave OR @od >= r.datum_odjave)
      )
    ORDER BY s.osnovna_cena, s.sprat, s.broj_sobe;

    IF @id_sobe IS NULL
        SET @poruka = N'Nema slobodnih soba koje ispunjavaju uslove u 
        traženom terminu.';
    ELSE
        SET @poruka = N'Predložena soba je prona?ena.';

END
GO


-- 8. Kreiranje uskladistene procedure sp_EvidentirajPlacanje koja dodaje placanje za rezervaciju u 
--    u tabelu placanja.

CREATE PROCEDURE dbo.sp_EvidentirajPlacanje
    @id_rezervacije INT,
    @iznos          DECIMAL(10,2),
    @metoda         NVARCHAR(20),
    @datum_placanja DATE = NULL,  
    @valuta         NVARCHAR(10) = N'RSD'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @iznos IS NULL OR @iznos <= 0
    BEGIN
        RAISERROR (N'Iznos pla?anja mora biti ve?i od nule.', 11, 1);
        RETURN;
    END;

    IF @datum_placanja IS NULL
        SET @datum_placanja = CAST(GETDATE() AS DATE);

    IF NOT EXISTS (SELECT 1 FROM dbo.Rezervacije WHERE id_rezervacije = @id_rezervacije)
    BEGIN
        RAISERROR (N'Rezervacija ne postoji.', 11, 1);
        RETURN;
    END;

    IF EXISTS (SELECT 1 FROM dbo.Rezervacije WHERE id_rezervacije = @id_rezervacije AND status = N'otkazano')
    BEGIN
        RAISERROR (N'Pla?anje nije dozvoljeno za otkazanu rezervaciju.', 11, 1);
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRAN;

            INSERT INTO dbo.Placanja (id_rezervacije, iznos, metoda, datum_placanja, valuta)
            VALUES (@id_rezervacije, @iznos, @metoda, @datum_placanja, @valuta);

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        DECLARE @msg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@msg, 11, 1);
    END CATCH
END
GO

-- 9. Kreiranje trigera trg_Usluge_Insert koji proverava podatke koji su uneti u tabelu usluge, sprecava
--    unos nedozvoljenih podataka i unos usluge za rezervaciju koja je otkazana ili odjavljena

CREATE TRIGGER dbo.trg_Usluge_Insert
ON dbo.Usluge
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        WHERE (i.kolicina IS NULL OR i.kolicina <= 0)
           OR (i.jedinicna_cena IS NULL OR i.jedinicna_cena < 0)
           OR (i.datum_usluge IS NULL)
    )
    BEGIN
        RAISERROR (N'Neispravna stavka usluge: koli?ina > 0, cena ? 0, 
        datum_usluge nije NULL.', 11, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN dbo.Rezervacije r ON r.id_rezervacije = i.id_rezervacije
        WHERE r.status IN (N'otkazano', N'odjavljen')
    )
    BEGIN
        RAISERROR (N'Nije dozvoljeno dodavanje usluge na otkazanu ili 
        odjavljenu rezervaciju.', 11, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END
GO


 -- 10. Dodavanje trigera trg_Rezervacije_UpdDel koji sprecava brisanje rezervacije koja je povezana sa nekom
 --     uslugom ili placanjem, proverava ispravnost unosa datuma prijave i odjave i automatski racuna i menja 
 --     broj nocenja ukoliko se neki od ovih datuma promeni.

CREATE TRIGGER dbo.trg_Rezervacije_UpdDel
ON dbo.Rezervacije
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    /* --- DELETE deo: blokiraj brisanje ako postoje povezani zapisi --- */
    IF EXISTS (SELECT 1 FROM deleted) AND NOT EXISTS (SELECT 1 FROM inserted)
    BEGIN
        IF EXISTS (
            SELECT 1
            FROM deleted d
            JOIN dbo.Usluge u ON u.id_rezervacije = d.id_rezervacije
        )
        OR EXISTS (
            SELECT 1
            FROM deleted d
            JOIN dbo.Placanja p ON p.id_rezervacije = d.id_rezervacije
        )
        BEGIN
            RAISERROR (N'Brisanje rezervacije nije dozvoljeno: postoje 
            povezane usluge ili pla?anja.', 11, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END
        RETURN;
    END

    IF EXISTS (
        SELECT 1
        FROM inserted i
        WHERE i.datum_odjave < i.datum_prijave
    )
    BEGIN
        RAISERROR (N'Datum odjave ne može biti pre datuma prijave.', 11, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    IF (UPDATE(datum_prijave) OR UPDATE(datum_odjave))
    BEGIN
        ;WITH src AS (
            SELECT 
                i.id_rezervacije,
                CASE 
                    WHEN DATEDIFF(DAY, i.datum_prijave, i.datum_odjave) < 1 THEN 1
                    ELSE DATEDIFF(DAY, i.datum_prijave, i.datum_odjave)
                END AS novi_broj
            FROM inserted i
        )
        UPDATE r
        SET r.broj_nocenja = s.novi_broj
        FROM dbo.Rezervacije r
        JOIN src s ON s.id_rezervacije = r.id_rezervacije;
    END
END
GO



