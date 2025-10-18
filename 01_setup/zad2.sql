--CREATE DATABASE lab2;
--CREATE EXTENSION postgis;

--Zad4
CREATE TABLE IF NOT EXISTS buildings (
    id SERIAL PRIMARY KEY,
    name TEXT,
    geom GEOMETRY
);

CREATE TABLE IF NOT EXISTS roads (
    id SERIAL PRIMARY KEY,
    name TEXT,
    geom GEOMETRY
);

CREATE TABLE IF NOT EXISTS poi (
    id SERIAL PRIMARY KEY,
    name TEXT,
    geom GEOMETRY
);

--Zad5
INSERT INTO buildings (name, geom) VALUES
('BuildingA', ST_GeomFromText('POLYGON((8 1.5, 8 4,  10.5 4, 10.5 1.5, 8 1.5))')),
('BuildingB', ST_GeomFromText('POLYGON((4 5, 4 7, 6 7, 6 5, 4 5))')),
('BuildingC', ST_GeomFromText('POLYGON((3 6, 3 8, 5 8, 5 6, 3 6))')),
('BuildingD', ST_GeomFromText('POLYGON((9 8, 9 9, 10 9, 10 8, 9 8))')),
('BuildingF', ST_GeomFromText('POLYGON((1 1, 1 2, 2 2, 2 1, 1 1))'));

INSERT INTO roads (name, geom) VALUES
('RoadX', ST_GeomFromText('LINESTRING(0 4.5, 12 4.5)')),
('RoadY', ST_GeomFromText('LINESTRING(7.5 0, 7.5 10.5)'));

INSERT INTO poi (name, geom) VALUES
('G', ST_GeomFromText('POINT(1 3.5)')),
('H', ST_GeomFromText('POINT(5.5 1.5)')),
('I', ST_GeomFromText('POINT(9.5 6)')),
('J', ST_GeomFromText('POINT(6.5 6)')),
('K', ST_GeomFromText('POINT(6 9.5)'));

SELECT * FROM buildings;
SELECT * FROM roads;
SELECT * FROM poi;

--Zad6
--a) dlugosc drog
SELECT SUM(ST_Length(geom)) AS roads_length
FROM roads;

--b) wypisac geometrie,pole i obw dla budynkuA
SELECT name,
    ST_AsText(geom) AS wkt_geometry,     --geometria jako wspolrzedne
    ST_Area(geom) AS area,
    ST_Perimeter(geom) AS perimeter
FROM buildings
WHERE name = 'BuildingA';

--c) nazwa i pole wszystkich poligonow budynków, posortowane
SELECT name, ST_Area(geom) AS area
FROM buildings
ORDER BY name;

--d) nazwy i obw 2 najwiekszych budynkow
SELECT name,
    ST_Perimeter(geom) AS Perimeter,
    ST_Area(geom) AS Area
FROM buildings
ORDER BY area DESC
LIMIT 2;

--e) najkrotsza odleglosc między C i K
SELECT ST_Distance(buildings.geom, poi.geom) AS distance --mierzy odl miedzy obiektami
FROM buildings
JOIN poi ON poi.name = 'K' 			--dolaczenie punktu
WHERE buildings.name = 'BuildingC';


--f) pole czesci budynku C, ktora jest w odl >0.5 od B
SELECT ST_Area(c.geom) -																	 --roznica pola - czesc wspolna				
						ST_Area(ST_Intersection(c.geom, 									 --czesc C wspolna z buforem
													ST_Buffer(b.geom, 0.5))) AS area_outside --bufor wokol B
FROM buildings c, buildings b
WHERE c.name = 'BuildingC' AND b.name = 'BuildingB';


--g) budynki, ktory centroid jest nad roadX
SELECT b.name
FROM buildings b
JOIN roads r ON r.name = 'RoadX'
WHERE ST_Y(ST_Centroid(b.geom)) > ST_Y(ST_Centroid(r.geom)); --wspl Y centroidu budynku > wspl Y centroidu drogi


--h) pole nie-wspolnej czesci poligonow
SELECT ST_Area(b.geom) 																				--pole budynku + pole obiektu - 2x wspolna czesc z tych obiektow
    + ST_Area(ST_GeomFromText('POLYGON((4 7, 6 7, 6 8, 4 8, 4 7))'))
    - 2*ST_Area(ST_Intersection(b.geom, ST_GeomFromText('POLYGON((4 7, 6 7, 6 8, 4 8, 4 7))')))
    AS non_common_area
FROM buildings b
WHERE b.name = 'BuildingC';


