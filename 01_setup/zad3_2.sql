--SELECT count(*) FROM t2018_kar_buildings;
--SELECT count(*) FROM t2019_kar_buildings;

------------------------- Zadanie 1 -------------------------------------
--nowe budynki w 2019
SELECT b2019.*
FROM t2019_kar_buildings b2019
LEFT JOIN t2018_kar_buildings b2018
ON ST_Equals(b2019.geom, b2018.geom)
WHERE b2018.geom IS NULL;

--wyremontowane budynki
SELECT b2018.geom AS geom_2018, b2019.geom AS geom_2019
FROM t2018_kar_buildings b2018
JOIN t2019_kar_buildings b2019
ON ST_Intersects(b2018.geom, b2019.geom)
WHERE NOT ST_Equals(b2018.geom, b2019.geom);

------------------------- Zadanie 2 -------------------------------------
--SELECT count(*) FROM t2018_kar_poi;
--SELECT count(*) FROM t2019_kar_poi;
CREATE VIEW diff_in_buildings AS
(
    --wybudowane
    SELECT b2019.geom
    FROM t2019_kar_buildings b2019
    LEFT JOIN t2018_kar_buildings b2018
    ON ST_Equals(b2019.geom, b2018.geom)
    WHERE b2018.geom IS NULL

    UNION

    --remontowane
    SELECT b2019.geom
    FROM t2018_kar_buildings b2018
    JOIN t2019_kar_buildings b2019
    ON ST_Intersects(b2018.geom, b2019.geom)
    WHERE NOT ST_Equals(b2018.geom, b2019.geom)
);

--w odleglosci 500m
CREATE VIEW new_poi AS
SELECT p2019.*
FROM t2019_kar_poi p2019
LEFT JOIN t2018_kar_poi p2018
ON ST_Equals(p2019.geom, p2018.geom)
WHERE p2018.geom IS NULL;

--nowe poi w odleglosci 500m od nowych/remontowanych budynkow
SELECT np.*
FROM new_poi np
JOIN diff_in_buildings cb
ON ST_DWithin(np.geom, cb.geom, 500);

--policzone wedlug kategorii
SELECT np.type, COUNT(*) AS count
FROM new_poi np
JOIN diff_in_buildings dib
ON ST_DWithin(np.geom, dib.geom, 500)
GROUP BY np.type
ORDER BY count DESC;

------------------------- Zadanie 3 -------------------------------------
--jaki system teraz jest -> 4326
SELECT ST_SRID(geom)
FROM t2019_streets
LIMIT 1;

--zmiana ukladu na 3068
CREATE TABLE streets AS
SELECT *, ST_Transform(geom, 3068) AS reprojected --przetransformowanie wspolrzednych
FROM t2019_streets;

ALTER TABLE streets
ALTER COLUMN reprojected
TYPE geometry USING ST_SetSRID(reprojected, 3068); --zapisanie do jakego ukladu przeszlismy

SELECT ST_SRID(geom) FROM streets LIMIT 5; --upewnienie sie

------------------------- Zadanie 4 -------------------------------------
CREATE TABLE input_points (
    id SERIAL PRIMARY KEY,
    geom GEOMETRY(Point, 4326)
);

--dodanie dwoch punktow
INSERT INTO input_points (geom) VALUES
(ST_SetSRID(ST_MakePoint(8.36093, 49.03174), 4326)),
(ST_SetSRID(ST_MakePoint(8.39876, 49.00644), 4326));

SELECT id, ST_AsText(geom) FROM input_points;

------------------------- Zadanie 5 -------------------------------------
--zmiana ukladu wspl
ALTER TABLE input_points
  ALTER COLUMN geom TYPE geometry(Point, 3068)
  USING ST_Transform(geom, 3068);

--wyswietlenie
SELECT id, ST_AsText(geom), ST_SRID(geom) FROM input_points;


------------------------- Zadanie 6 -------------------------------------
--tablica skrzyzowan, zmiana na uklad 3068
CREATE TABLE street_node AS
SELECT *, ST_Transform(geom, 3068) AS geom_3068
FROM t2019_node;

--laczymy dwa punktyw linie, tworzymy strefe 200m i wybieramy elementy, ktore sa w tej strefie
WITH line AS (
  SELECT ST_MakeLine(geom ORDER BY id) AS geom
  FROM input_points
),
buffer AS (
  SELECT ST_Buffer(geom, 200) AS geom
  FROM line
)
SELECT sn.*
FROM t2019_node sn
WHERE ST_Intersects(
        ST_Transform(sn.geom, 3068),
        (SELECT geom FROM buffer)
      );



------------------------- Zadanie 7 -------------------------------------
--zmiana ukladow
WITH parks AS (
    SELECT ST_Transform(geom, 3068) AS geom
    FROM t2019_land
),
sports_shops AS (
    SELECT ST_Transform(geom, 3068) AS geom
    FROM t2019_kar_poi
    WHERE type = 'Sporting Goods Store'
)

--tylko sklepy w odleglosci 300m od parku
SELECT s.geom
FROM sports_shops s
JOIN parks p
ON ST_DWithin(s.geom, p.geom, 300);

------------------------- Zadanie 8 -------------------------------------
--punkty przeciecia torow i rzek w nowej tabeli (potencjalne mosty)
CREATE TABLE IF NOT EXISTS t2019_bridges AS
SELECT 
    ST_Intersection(r.geom, w.geom) AS geom
FROM t2019_rail r
JOIN t2019_water w
ON ST_Intersects(r.geom, w.geom)
WHERE GeometryType(ST_Intersection(r.geom, w.geom)) = 'POINT';

--ilosc
SELECT COUNT(*) FROM t2019_bridges;

--tabela
SELECT *, ST_AsText(geom)
FROM t2019_bridges
LIMIT 20;
