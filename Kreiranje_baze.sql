
CREATE DATABASE HOTEL 
COLLATE Serbian_Latin_100_CI_AI;
GO

USE HOTEL;
GO


CREATE TABLE dbo.Gosti (
  id_gosta     INT IDENTITY(1,1),
  ime          NVARCHAR(25)  NOT NULL,
  prezime      NVARCHAR(50)  NOT NULL,
  telefon      NVARCHAR(30)  NULL,
  email        NVARCHAR(100) NULL,
  PRIMARY KEY (id_gosta)
);


CREATE TABLE dbo.Sobe (
  id_sobe       INT IDENTITY(1,1),
  broj_sobe     NVARCHAR(10) NOT NULL,
  sprat         SMALLINT     NULL,
  tip_kreveta   NVARCHAR(30) NULL,
  osnovna_cena  DECIMAL(10,2) NOT NULL,
  status        NVARCHAR(20) NULL,
  PRIMARY KEY (id_sobe)
);


CREATE TABLE dbo.Zaposleni (
  id_zaposlenog   INT IDENTITY(1,1),
  ime             NVARCHAR(25) NOT NULL,
  prezime         NVARCHAR(50) NOT NULL,
  pozicija        NVARCHAR(50) NULL,
  telefon         NVARCHAR(30) NULL,
  email           NVARCHAR(100) NULL,
  datum_zaposlenja DATE       NULL,
  aktivan         BIT         NULL,
  PRIMARY KEY (id_zaposlenog)
);


CREATE TABLE dbo.Rezervacije (
  id_rezervacije  INT IDENTITY(1,1),
  id_gosta        INT NOT NULL,
  id_sobe         INT NOT NULL,
  id_zaposlenog   INT NULL,
  datum_prijave   DATE NOT NULL,
  datum_odjave    DATE NOT NULL,
  broj_nocenja    SMALLINT NOT NULL,
  broj_gostiju    SMALLINT NOT NULL,
  status          NVARCHAR(20) NOT NULL,
  datum_kreiranja DATE NOT NULL,
  PRIMARY KEY (id_rezervacije)
);


CREATE TABLE dbo.Placanja (
  id_placanja     INT IDENTITY(1,1),
  id_rezervacije  INT NOT NULL,
  iznos           DECIMAL(10,2) NOT NULL,
  metoda          NVARCHAR(20)  NOT NULL,
  datum_placanja  DATE          NOT NULL,
  valuta          NVARCHAR(10)  NULL,
  PRIMARY KEY (id_placanja)
);


CREATE TABLE dbo.Usluge (
  id_usluge       INT IDENTITY(1,1),
  id_rezervacije  INT NOT NULL,
  id_zaposlenog   INT NULL,
  datum_usluge    DATE          NOT NULL,
  opis_usluge     NVARCHAR(200) NOT NULL,
  kolicina        SMALLINT      NOT NULL,
  jedinicna_cena  DECIMAL(10,2) NOT NULL,
  PRIMARY KEY (id_usluge)
);


ALTER TABLE dbo.Rezervacije
  ADD FOREIGN KEY (id_gosta) REFERENCES dbo.Gosti(id_gosta);

ALTER TABLE dbo.Rezervacije
  ADD FOREIGN KEY (id_sobe) REFERENCES dbo.Sobe(id_sobe);

ALTER TABLE dbo.Rezervacije
  ADD FOREIGN KEY (id_zaposlenog) REFERENCES dbo.Zaposleni(id_zaposlenog);

ALTER TABLE dbo.Placanja
  ADD FOREIGN KEY (id_rezervacije) REFERENCES dbo.Rezervacije(id_rezervacije);

ALTER TABLE dbo.Usluge
  ADD FOREIGN KEY (id_rezervacije) REFERENCES dbo.Rezervacije(id_rezervacije);

ALTER TABLE dbo.Usluge
  ADD FOREIGN KEY (id_zaposlenog) REFERENCES dbo.Zaposleni(id_zaposlenog);



--Popunjavanje tabele podacima


INSERT INTO Gosti (ime, prezime, telefon, email) VALUES
('Marko', 'Petrovic', '0601111111', 'marko.petrovic@mail.com'),
('Jelena', 'Jovanovic', '0612222222', 'jelena.jovanovic@mail.com'),
('Nikola', 'Ilic', '0623333333', 'nikola.ilic@mail.com'),
('Ana', 'Stankovic', '0634444444', 'ana.stankovic@mail.com'),
('Miloš', 'Djordjevic', '0645555555', 'milos.djordjevic@mail.com'),
('Ivana', 'Mihajlovic', '0656666666', 'ivana.mihajlovic@mail.com'),
('Stefan', 'Lukic', '0667777777', 'stefan.lukic@mail.com'),
('Milica', 'Pavlovic', '0678888888', 'milica.pavlovic@mail.com'),
('Petar', 'Obradovic', '0689999999', 'petar.obradovic@mail.com'),
('Tamara', 'Simic', '0691010101', 'tamara.simic@mail.com');


INSERT INTO Sobe (broj_sobe, sprat, tip_kreveta, osnovna_cena, status) VALUES
('101', 1, 'Jednokrevetna', 3500, 'slobodna'),
('102', 1, 'Dvokrevetna', 5000, 'slobodna'),
('103', 1, 'Apartman', 8500, 'zauzeta'),
('201', 2, 'Jednokrevetna', 3600, 'slobodna'),
('202', 2, 'Dvokrevetna', 5200, 'zauzeta'),
('203', 2, 'Apartman', 9000, 'slobodna'),
('301', 3, 'Jednokrevetna', 3700, 'slobodna'),
('302', 3, 'Dvokrevetna', 5400, 'zauzeta'),
('303', 3, 'Apartman', 9200, 'slobodna'),
('304', 3, 'Jednokrevetna', 3550, 'slobodna');


INSERT INTO Zaposleni (ime, prezime, pozicija, telefon, email, datum_zaposlenja, aktivan) VALUES
('Maja', 'Nikolic', 'Recepcioner', '060111222', 'maja.nikolic@hotel.com', '2020-05-15', 1),
('Nenad', 'Peric', 'Menadžer', '060333444', 'nenad.peric@hotel.com', '2018-03-10', 1),
('Sara', 'Kovacevic', 'Sobarica', '060555666', 'sara.kovacevic@hotel.com', '2021-07-20', 1),
('Milan', 'Ristic', 'Recepcioner', '060777888', 'milan.ristic@hotel.com', '2019-11-01', 1),
('Ivana', 'Petric', 'Sobarica', '060999000', 'ivana.petric@hotel.com', '2022-01-12', 1),
('Dejan', 'Arsic', 'Konobar', '061111222', 'dejan.arsic@hotel.com', '2020-09-05', 1),
('Dragana', 'Vasic', 'Menadžer', '061333444', 'dragana.vasic@hotel.com', '2017-06-23', 1),
('Aleksandar', 'Djukic', 'Recepcioner', '061555666', 'aleksandar.djuki?@hotel.com', '2023-02-18', 1),
('Bojan', 'Markovic', 'Sobar', '061777888', 'bojan.markovic@hotel.com', '2021-04-09', 1),
('Jovana', 'Radovic', 'Recepcioner', '061999000', 'jovana.radovic@hotel.com', '2022-08-25', 1);



INSERT INTO Rezervacije (id_gosta, id_sobe, id_zaposlenog, datum_prijave, datum_odjave, broj_nocenja, broj_gostiju, status, datum_kreiranja) VALUES
(3, 2, 1, '2023-06-01', '2023-06-04', 3,  1, 'odjavljen', '2023-05-15'),
(1, 5, 4, '2023-06-10', '2023-06-14', 4,  2, 'prijavljen', '2023-05-25'),
(7, 3, 2, '2023-07-05', '2023-07-12', 7, 2, 'rezervisano', '2023-06-20'),
(2, 8, 1, '2023-07-15', '2023-07-20', 5, 1, 'otkazano', '2023-06-28'),
(9, 6, 3, '2023-08-02', '2023-08-06', 4, 1, 'prijavljen', '2023-07-10'),
(4, 10, 5, '2023-08-15', '2023-08-22', 7, 3, 'rezervisano', '2023-07-30'),
(6, 1, 6, '2023-09-01', '2023-09-05', 4, 1, 'odjavljen', '2023-08-10'),
(10, 7, 8, '2023-09-18', '2023-09-22', 4, 2, 'rezervisano', '2023-08-25'),
(5, 9, 2, '2023-10-01', '2023-10-08', 7, 4, 'prijavljen', '2023-09-12'),
(8, 4, 7, '2023-10-12', '2023-10-15', 3, 1, 'rezervisano', '2023-09-20');



INSERT INTO Placanja (id_rezervacije, iznos, metoda, datum_placanja, valuta) VALUES
(1, 14000, 'gotovina', '2023-06-01', 'RSD'),
(2, 25000, 'kartica', '2023-06-10', 'RSD'),
(3, 0, 'online', '2023-07-01', 'RSD'),
(4, 10800, 'kartica', '2023-07-15', 'RSD'),
(5, 26000, 'gotovina', '2023-08-01', 'RSD'),
(6, 9000, 'kartica', '2023-08-20', 'RSD'),
(7, 14800, 'gotovina', '2023-09-05', 'RSD'),
(8, 11000, 'online', '2023-09-20', 'RSD'),
(9, 36800, 'kartica', '2023-10-01', 'RSD'),
(10, 17750, 'gotovina', '2023-10-15', 'RSD');



INSERT INTO Usluge (id_rezervacije, id_zaposlenog, datum_usluge, opis_usluge, kolicina, jedinicna_cena) VALUES
(1, 6, '2023-06-02', 'Minibar', 2, 600),
(2, 6, '2023-06-12', 'Spa tretman', 1, 3000),
(2, 6, '2023-06-13', 'Dorucak', 2, 800),
(4, 5, '2023-07-16', 'Pranje veša', 1, 1200),
(5, 5, '2023-08-05', 'Dorucak', 2, 800),
(6, 5, '2023-08-21', 'Wellness paket', 1, 5000),
(7, 3, '2023-09-07', 'Minibar', 1, 700),
(8, 3, '2023-09-20', 'Dorucak', 1, 400),
(9, 2, '2023-10-03', 'Spa tretman', 2, 3000),
(10, 4, '2023-10-16', 'Minibar', 3, 600);

