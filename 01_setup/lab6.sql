--SELECT * FROM vectors.places LIMIT 5;

--zmiana nazwy schema
ALTER SCHEMA schema_name RENAME TO Wesolowska;

--wyswietlenie tabel
SELECT * FROM rasters.dem LIMIT 10;
SELECT * FROM rasters.landsat8 LIMIT 10;


---------------------------- Tworzenie rastrów z istniejących rastrów i interakcja z wektorami ---------------------------------

--przecięcie rastra z wektorem
CREATE TABLE wesolowska.intersects AS
SELECT a.rast, b.municipality
FROM rasters.dem AS a, vectors.porto_parishes AS b
WHERE ST_Intersects(a.rast, b.geom) AND b.municipality ilike 'porto';

--odanie serial primary key:
alter table wesolowska.intersects
add column rid SERIAL PRIMARY KEY;

--utworzenie indeksu przestrzennego:
CREATE INDEX idx_intersects_rast_gist ON wesolowska.intersects
USING gist (ST_ConvexHull(rast));

--dodanie ograniczenia rastrowe (dla poprawności metadanych)
SELECT AddRasterConstraints('wesolowska'::name, 'intersects'::name,'rast'::name);

--obcinanie rastra na podstawie wektora
CREATE TABLE wesolowska.clip AS
SELECT ST_Clip(a.rast, b.geom, true), b.municipality
FROM rasters.dem AS a, vectors.porto_parishes AS b
WHERE ST_Intersects(a.rast, b.geom) AND b.municipality like 'PORTO';

--Połączenie wielu kafelków w jeden raster.
CREATE TABLE wesolowska.union AS
SELECT ST_Union(ST_Clip(a.rast, b.geom, true))
FROM rasters.dem AS a, vectors.porto_parishes AS b
WHERE b.municipality ilike 'porto' and ST_Intersects(b.geom,a.rast);


---------------------------- Tworzenie rastrów z wektorów (rastrowanie) ----------------------------

--rastrowanie każdej parafii osobno
CREATE TABLE wesolowska.porto_parishes AS
WITH r AS (
SELECT rast FROM rasters.dem
LIMIT 1
)
SELECT ST_AsRaster(a.geom,r.rast,'8BUI',a.id,-32767) AS rast
FROM vectors.porto_parishes AS a, r
WHERE a.municipality ilike 'porto';

--połączenie w jeden raster
DROP TABLE wesolowska.porto_parishes; --> drop table porto_parishes first
CREATE TABLE wesolowska.porto_parishes AS
WITH r AS (
SELECT rast FROM rasters.dem
LIMIT 1
)
SELECT st_union(ST_AsRaster(a.geom,r.rast,'8BUI',a.id,-32767)) AS rast
FROM vectors.porto_parishes AS a, r
WHERE a.municipality ilike 'porto';

--podział rastra na kafelki 128×128
DROP TABLE wesolowska.porto_parishes; --> drop table porto_parishes first
CREATE TABLE wesolowska.porto_parishes AS
WITH r AS (
SELECT rast FROM rasters.dem
LIMIT 1 )
SELECT st_tile(st_union(ST_AsRaster(a.geom,r.rast,'8BUI',a.id,-32767)),128,128,true,-32767) AS rast
FROM vectors.porto_parishes AS a, r
WHERE a.municipality ilike 'porto';

SELECT * FROM wesolowska.porto_parishes LIMIT 10;

---------------------------- Konwertowanie rastrów na wektory (wektoryzowanie) ----------------------------

--przecięcie rastra z wektorem, zwraca geometrie pikseli
create table wesolowska.intersection as
SELECT a.rid,(ST_Intersection(b.geom,a.rast)).geom,(ST_Intersection(b.geom,a.rast)).val
FROM rasters.landsat8 AS a, vectors.porto_parishes AS b
WHERE b.parish ilike 'paranhos' and ST_Intersects(b.geom,a.rast);

--konwersja rastrow w wektory (poligony)
CREATE TABLE wesolowska.dumppolygons AS
SELECT a.rid,(ST_DumpAsPolygons(ST_Clip(a.rast,b.geom))).geom,(ST_DumpAsPolygons(ST_Clip(a.rast,b.geom))).val
FROM rasters.landsat8 AS a, vectors.porto_parishes AS b
WHERE b.parish ilike 'paranhos' and ST_Intersects(b.geom,a.rast);


---------------------------- Analiza rastrów ----------------------------

--wyodrębnienie pasma (np. NIR z 4. kanału Landsat)
CREATE TABLE wesolowska.landsat_nir AS
SELECT rid, ST_Band(rast,4) AS rast
FROM rasters.landsat8;

--wycięcie rastra DEM do granic parafii Paranhoss
CREATE TABLE wesolowska.paranhos_dem AS
SELECT a.rid,ST_Clip(a.rast, b.geom,true) as rast
FROM rasters.dem AS a, vectors.porto_parishes AS b
WHERE b.parish ilike 'paranhos' and ST_Intersects(b.geom,a.rast);

--obliczenie nachylenia terenu
CREATE TABLE wesolowska.paranhos_slope AS
SELECT a.rid,ST_Slope(a.rast,1,'32BF','PERCENTAGE') as rast
FROM wesolowska.paranhos_dem AS a;

--reklasyfikacja (podział wartości nachylenia na klasy)
CREATE TABLE wesolowska.paranhos_slope_reclass AS
SELECT a.rid,ST_Reclass(a.rast,1,']0-15]:1, (15-30]:2, (30-9999:3', '32BF',0)
FROM wesolowska.paranhos_slope AS a;

--statystyki dla każdego kafelka DEM
SELECT st_summarystats(a.rast) AS stats
FROM wesolowska.paranhos_dem AS a;

--statystyka łączna dla całego rastra
SELECT st_summarystats(ST_Union(a.rast))
FROM wesolowska.paranhos_dem AS a;

--SummaryStats z lepszą kontrolą złożonego typu danych
WITH t AS (
SELECT st_summarystats(ST_Union(a.rast)) AS stats
FROM wesolowska.paranhos_dem AS a
)
SELECT (stats).min,(stats).max,(stats).mean FROM t;

--statystyki dla każdej parafii Porto
WITH t AS (
SELECT b.parish AS parish, st_summarystats(ST_Union(ST_Clip(a.rast, b.geom,true))) AS stats
FROM rasters.dem AS a, vectors.porto_parishes AS b
WHERE b.municipality ilike 'porto' and ST_Intersects(b.geom,a.rast)
group by b.parish
)
SELECT parish,(stats).min,(stats).max,(stats).mean FROM t;

--odczyt wartości rastra w punktach
SELECT b.name,st_value(a.rast,(ST_Dump(b.geom)).geom)
FROM
rasters.dem a, vectors.places AS b
WHERE ST_Intersects(a.rast,b.geom)
ORDER BY b.name;


---------------------------- Topographic Position Index (TPI) ----------------------------

--utworzy raster tpi30 o tej samej rozdzielczości co DEM
create table wesolowska.tpi30 as
select ST_TPI(a.rast,1) as rast
from rasters.dem a;

--Poniższa kwerenda utworzy indeks przestrzenny:
CREATE INDEX idx_tpi30_rast_gist ON wesolowska.tpi30
USING gist (ST_ConvexHull(rast));

--Dodanie constraintów:
SELECT AddRasterConstraints('wesolowska'::name, 'tpi30'::name,'rast'::name);


---------------------------- MOJE ROZWIAZANIE ----------------------------
--Zapytanie TPI tylko dla Porto
CREATE TABLE wesolowska.tpi30_porto AS
SELECT ST_TPI(a.rast, 1) AS rast
FROM rasters.dem AS a, vectors.porto_parishes AS b
WHERE b.municipality ILIKE 'porto'
  AND ST_Intersects(a.rast, b.geom);

--indeks przestrzenny i dodanie constraint
CREATE INDEX idx_tpi30_porto_rast_gist
ON wesolowska.tpi30_porto
USING gist (ST_ConvexHull(rast));

SELECT AddRasterConstraints('wesolowska'::name, 'tpi30_porto'::name, 'rast'::name);



---------------------------- Algebra map ----------------------------
-- Wzór na NDVI:   NDVI=(NIR-Red)/(NIR+Red)

--SPOSOB I: algebra map z wyrażeniem
CREATE TABLE wesolowska.porto_ndvi AS
WITH r AS (
SELECT a.rid,ST_Clip(a.rast, b.geom,true) AS rast
FROM rasters.landsat8 AS a, vectors.porto_parishes AS b
WHERE b.municipality ilike 'porto' and ST_Intersects(b.geom,a.rast)
)
SELECT
r.rid,ST_MapAlgebra(
r.rast, 1,
r.rast, 4,
'([rast2.val] - [rast1.val]) / ([rast2.val] + [rast1.val])::float','32BF'
) AS rast
FROM r;

--indeks przestrzenny, constraint
CREATE INDEX idx_porto_ndvi_rast_gist ON wesolowska.porto_ndvi
USING gist (ST_ConvexHull(rast));

SELECT AddRasterConstraints('wesolowska'::name, 'porto_ndvi'::name,'rast'::name);


--SPOSOB II: Funkcja zwrotna
create or replace function wesolowska.ndvi(
value double precision [] [] [],
pos integer [][],
VARIADIC userargs text []
)
RETURNS double precision AS
$$
BEGIN
--RAISE NOTICE 'Pixel Value: %', value [1][1][1];-->dla debugu
RETURN (value [2][1][1] - value [1][1][1])/(value [2][1][1]+value [1][1][1]); --> NDVI obliczenia
END;
$$
LANGUAGE 'plpgsql' IMMUTABLE COST 1000;

--W kwerendzie algebry map należy można wywołać zdefiniowaną wcześniej funkcję:
CREATE TABLE wesolowska.porto_ndvi2 AS
WITH r AS (
SELECT a.rid,ST_Clip(a.rast, b.geom,true) AS rast
FROM rasters.landsat8 AS a, vectors.porto_parishes AS b
WHERE b.municipality ilike 'porto' and ST_Intersects(b.geom,a.rast)
)
SELECT
r.rid,ST_MapAlgebra(
r.rast, ARRAY[1,4],
'wesolowska.ndvi(double precision[], integer[],text[])'::regprocedure, --> funckja
'32BF'::text
) AS rast
FROM r;

--indeks przestrzenny, constraint
CREATE INDEX idx_porto_ndvi2_rast_gist ON wesolowska.porto_ndvi2
USING gist (ST_ConvexHull(rast));

SELECT AddRasterConstraints('wesolowska'::name, 'porto_ndvi2'::name,'rast'::name);



---------------------------- Eksport danych ----------------------------

--ST_AsTiff tworzy dane wyjściowe jako binarną reprezentację pliku tiff
SELECT ST_AsTiff(ST_Union(rast))
FROM wesolowska.porto_ndvi;


--ST_AsGDALRaster dane wyjściowe są reprezentacją binarną dowolnego formatu GDAL
SELECT ST_AsGDALRaster(ST_Union(rast), 'GTiff', ARRAY['COMPRESS=DEFLATE', 'PREDICTOR=2', 'PZLEVEL=9'])
FROM wesolowska.porto_ndvi;


--Zapisywanie danych na dysku za pomocą dużego obiektu (large object, lo)
CREATE TABLE tmp_out AS
SELECT lo_from_bytea(0,
ST_AsGDALRaster(ST_Union(rast), 'GTiff', ARRAY['COMPRESS=DEFLATE', 'PREDICTOR=2', 'PZLEVEL=9'])
) AS loid
FROM wesolowska.porto_ndvi;


SELECT lo_export(loid, 'G:\myraster.tiff')
FROM tmp_out;

SELECT lo_unlink(loid)
FROM tmp_out; -- usuwa large object
