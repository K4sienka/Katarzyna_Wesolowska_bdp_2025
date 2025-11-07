--CREATE EXTENSION postgis;

CREATE TABLE IF NOT EXISTS obiekty (
    id SERIAL PRIMARY KEY,
    name TEXT,
    geom GEOMETRY
);

--obiekt 1
INSERT INTO obiekty (name, geom) VALUES
('obiekt1', ST_GeomFromText('LINESTRING(0 1, 1 1, 2 0, 3 1, 4 2, 5 1, 6 1)', 0));


--obiek 2
INSERT INTO obiekty (name, geom) VALUES
('obiekt2', ST_GeomFromText('POLYGON((10 6, 14 6, 16 4, 14 2, 12 0, 10 2, 10 6), (11 2, 12 3, 13 2, 12 1, 11 2))', 0));


--obiek 3
INSERT INTO obiekty (name, geom) VALUES
('obiekt3', ST_GeomFromText('POLYGON((7 15, 10 17, 12 13, 7 15))', 0));


--obiek 4
INSERT INTO obiekty (name, geom) VALUES
('obiekt4', ST_GeomFromText('LINESTRING(20 20, 25 25, 27 24, 25 22, 26 21, 22 19, 20.5 19.5)', 0));


--obiek 5
INSERT INTO obiekty (name, geom) VALUES
('obiekt5', ST_GeomFromEWKT('MULTIPOINT Z ((30 30 59), (38 32 234))'));


--obiek 6
INSERT INTO obiekty (name, geom) VALUES
('obiekt6', ST_GeomFromText('GEOMETRYCOLLECTION(LINESTRING(1 1, 3 2), POINT(4 2))', 0));

--Wyznacz pole powierzchni bufora o wielkości 5 jednostek, który został utworzony wokół najkrótszej linii łączącej obiekt 3 i 4.
SELECT 
    ST_Area(ST_Buffer(ST_ShortestLine(o3.geom, o4.geom), 5)) AS buffer_area
FROM obiekty o3, obiekty o4
WHERE o3.name = 'obiekt3' AND o4.name = 'obiekt4';

--Zamień obiekt4 na poligon. Jaki warunek musi być spełniony, aby można było wykonać to zadanie? Zapewnij te warunki -> figura musi byc zamknieta
UPDATE obiekty
SET geom = ST_GeomFromText('POLYGON((20 20, 25 25, 27 24, 25 22, 26 21, 22 19, 20.5 19.5, 20 20))', 0)
WHERE name = 'obiekt4';

--W tabeli obiekty, jako obiekt7 zapisz obiekt złożony z obiektu 3 i obiektu 4.
INSERT INTO obiekty (name, geom)
SELECT 'obiekt7', ST_Collect(o3.geom, o4.geom)
FROM obiekty o3, obiekty o4
WHERE o3.name = 'obiekt3' AND o4.name = 'obiekt4';

SELECT id, name FROM obiekty; --podejrzenie

--Wyznacz pole powierzchni wszystkich buforów o wielkości 5 jednostek, które zostały utworzone wokół obiektów nie zawierających łuków.
-- ST_HasArc() zwraca TRUE jesli obiekt ma luki
SELECT 
    name, ST_Area(ST_Buffer(geom, 5)) AS buffer_area
FROM obiekty
WHERE NOT ST_HasArc(geom);
