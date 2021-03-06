## Assessment and modeling of Soil Organic Carbon Stocks for Wetlands and Peatlands in the tropics
## Tom.Hengl@isric.org

load(".RData")
library(rgdal)
library(utils)
library(snowfall)
library(raster)
library(RSAGA)
library(plotKML)
library(psych)
library(scales)
library(R.utils)
library(plotKML)
library(GSIF)
library(parallel)
library(doParallel)
library(foreign)
library(tools)
library(doSNOW)
library(doMC)
library(BSDA)
plotKML.env(convert="convert", show.env=FALSE)

if(.Platform$OS.type == "windows"){
  gdal.dir <- shortPathName("C:/Program files/GDAL")
  gdal_translate <- paste0(gdal.dir, "/gdal_translate.exe")
  gdalwarp <- paste0(gdal.dir, "/gdalwarp.exe") 
} else {
  gdal_translate = "/usr/bin/gdal_translate"
  gdalwarp = "/usr/bin/gdalwarp"
}

## List of property maps:
fao.lst <- c("Sapric.Histosols", "Hemic.Histosols", "Fibric.Histosols", "Cryic.Histosols", "Histic.Albeluvisols")
usda.lst <- c("Saprists", "Hemists", "Folists", "Fibrists")

## resample to 1 km resolution Tropics only:
system(paste0(gdalwarp, ' /data/GEOG/HISTPR_1km_ll.tif TROP_HISTPR_1km_ll.tif -te -180 -36 180 36 -co \"COMPRESS=DEFLATE\"'))
for(i in fao.lst){ system(paste0(gdalwarp, ' /data/GEOG/TAXNWRB_', i, '_1km_ll.tif TROP_', i, '_1km_ll.tif -te -180 -36 180 36 -co \"COMPRESS=DEFLATE\"')) }

## Resample in parallel:
orc.lst <- paste0("OCSTHA_M_sd", 1:6)
bld.lst <- paste0("BLDFIE_M_sl", 1:7)
soc.lst <- paste0("ORCDRC_M_sl", 1:7)
t.lst <- c(orc.lst, bld.lst, soc.lst)
sfInit(parallel=TRUE, cpus=length(t.lst))
sfLibrary(raster)
sfLibrary(rgdal)
sfExport("gdalwarp","t.lst")
x <- sfClusterApplyLB(t.lst, function(x){ try( if(!file.exists(paste0('TROP_', x, '_1km_ll.tif'))){ system(paste0(gdalwarp, ' /data/GEOG/', x, '_1km_ll.tif TROP_', x, '_1km_ll.tif -te -180 -36 180 36 -co \"COMPRESS=DEFLATE\"')) } ) })
sfStop()
file.copy(from="TROP_OCSTHA_M_sd6_1km_ll.tif", to="TROP_OCSTHA_2m_1km_ll.tif")
## sum up OCS values for 0-1 m
sD <- raster::stack(paste0('TROP_OCSTHA_M_sd', 1:5, '_1km_ll.tif'))
sumf <- function(x){calc(x, sum, na.rm=TRUE)}
## run in parallel:
beginCluster()
r1 <- clusterR(sD, fun=sumf, filename="TROP_OCSTHA_1m_1km_ll.tif", datatype="INT2S", options=c("COMPRESS=DEFLATE"))
endCluster()

#for(i in orc.lst){ system(paste0(gdalwarp, ' /data/GEOG/', i, '_1km_ll.tif TROP_', i, '_1km_ll.tif -te -180 -36 180 36 -co \"COMPRESS=DEFLATE\"')) }

## plot HWSD and SoilGrids estimated SOCS next to each other:
rob = "+proj=robin +lon_0=0 +x_0=0 +y_0=0 +ellps=WGS84 +datum=WGS84 +units=m +no_defs"
system(paste0(gdalwarp, ' TROP_OCSTHA_1m_1km_ll.tif OCSTHA_1m_10km.tif -r \"average\" -tr 0.1 0.1 -co \"COMPRESS=DEFLATE\" -dstnodata -9999'))
system(paste0(gdalwarp, ' TROP_OCSTHA_2m_1km_ll.tif OCSTHA_2m_10km.tif -r \"average\" -tr 0.1 0.1 -co \"COMPRESS=DEFLATE\" -dstnodata -9999'))
system(paste0(gdalwarp, ' TROP_HISTPR_1km_ll.tif HISTPR_10km.tif -r \"average\" -tr 0.1 0.1 -co \"COMPRESS=DEFLATE\" -dstnodata 255'))

## Soil points:
load("/data/models/SPROPS/ovA.rda")
TROP_xy <- ovA[ovA$LATWGS84>-36&ovA$LATWGS84<36,c("SOURCEID","LONWGS84","LATWGS84","SOURCEDB","UHDICM","LHDICM","HZDTXT","ORCDRC","BLD","CRFVOL")]
TROP_xy <- TROP_xy[!is.na(TROP_xy$LATWGS84)&!is.na(TROP_xy$ORCDRC),]
unlink("TROP_soil_profiles.csv.gz")
write.csv(TROP_xy, file="TROP_soil_profiles.csv")
gzip("TROP_soil_profiles.csv")
summary(as.factor(TROP_xy$SOURCEDB))
plot(TROP_xy$LONWGS84, TROP_xy$LATWGS84, pch="+", col="red")
rm(ovA)

load("/data/models/TAXOUSDA/ov.TAXOUSDA.rda")
TROP_usda <- ov[ov$LATWGS84>-36&ov$LATWGS84<36,c("SOURCEID","LOC_ID","LATWGS84","SOURCEDB","TAXOUSDA.f")]
TROP_usda$LONWGS84 <- as.numeric(sapply(paste(TROP_usda$LOC_ID), function(i){strsplit(i, "_")[[1]][1]}))
TROP_usda$HISTPR <- 0
TROP_usda$HISTPR[grep(TROP_usda$TAXOUSDA.f, pattern="ist", ignore.case=TRUE)] <- 1
summary(as.factor(TROP_usda$HISTPR))
TROP_usda <- TROP_usda[!is.na(TROP_usda$LATWGS84)&!is.na(TROP_usda$TAXOUSDA.f),]
unlink("TROP_soil_types_USDA.csv.gz")
write.csv(TROP_usda[,c("SOURCEID","SOURCEDB","LONWGS84","LATWGS84","TAXOUSDA.f","HISTPR")], file="TROP_soil_types_USDA.csv")
gzip("TROP_soil_types_USDA.csv")
summary(TROP_usda$SOURCEDB)
points(TROP_usda$LONWGS84, TROP_usda$LATWGS84, pch="+")

load("/data/models/TAXNWRB/ov.TAXNWRB.rda")
TROP_wrb <- ov[ov$LATWGS84>-36&ov$LATWGS84<36,c("SOURCEID","LOC_ID","LATWGS84","SOURCEDB","TAXNWRB.f")]
TROP_wrb$LONWGS84 <- as.numeric(sapply(paste(TROP_wrb$LOC_ID), function(i){strsplit(i, "_")[[1]][1]}))
TROP_wrb$HISTPR <- 0
TROP_wrb$HISTPR[grep(TROP_wrb$TAXNWRB.f, pattern="hist", ignore.case=TRUE)] <- 1
summary(as.factor(TROP_wrb$HISTPR))
TROP_wrb <- TROP_wrb[!is.na(TROP_wrb$LATWGS84)&!is.na(TROP_wrb$TAXNWRB.f),]
unlink("TROP_soil_types_WRB.csv.gz")
write.csv(TROP_wrb[,c("SOURCEID","SOURCEDB","LONWGS84","LATWGS84","TAXNWRB.f","HISTPR")], file="TROP_soil_types_WRB.csv")
gzip("TROP_soil_types_WRB.csv")
rm(ov)

## Wetlands / land cover classes:
glc.lst <- paste0("/data/GlobCover30/", c(paste0("L0",1:9,"GLC3a.tif"), "L10GLC3a.tif", "LMKGLC3a.tif"))
sfInit(parallel=TRUE, cpus=length(glc.lst))
sfLibrary(raster)
sfLibrary(rgdal)
sfExport("gdalwarp","glc.lst")
x <- sfClusterApplyLB(glc.lst, function(x){ try( system(paste0(gdalwarp, ' ', x, ' ', gsub("3a", "_10km", basename(x)),' -r \"average\" -tr 0.1 0.1 -te -180 -36 180 36 -co \"COMPRESS=DEFLATE\"')) ) })
sfStop()

## Upper and lower limits for OCS at 10 km:
tif.lst <- paste0("/data/GEOG/", c(paste0("ORCDRC_M_sl", 1:7, "_1km_ll.tif"), paste0("BLDFIE_M_sl", 1:7, "_1km_ll.tif"), paste0("CRFVOL_M_sl", 1:7, "_1km_ll.tif")))
sfInit(parallel=TRUE, cpus=length(tif.lst))
sfLibrary(raster)
sfLibrary(rgdal)
sfExport("gdalwarp","tif.lst")
x <- sfClusterApplyLB(tif.lst, function(x){ try( system(paste0(gdalwarp, ' ', x, ' ', gsub("1km", "10km", basename(x)),' -r \"average\" -tr 0.1 0.1 -te -180 -36 180 36 -co \"COMPRESS=DEFLATE\"')) ) })
sfStop()

## Countries:
download.file("http://www.naturalearthdata.com/http//www.naturalearthdata.com/download/10m/cultural/ne_10m_admin_0_countries.zip", "ne_10m_admin_0_countries.zip")
system("7za e ne_10m_admin_0_countries.zip")
## Rasterize:
countries.dbf <- read.dbf("ne_10m_admin_0_countries.dbf")
countries.dbf[["dbf"]]$NAME_INT = as.integer(countries.dbf[["dbf"]]$NAME)
write.dbf(countries.dbf, out.name="ne_10m_admin_0_countries.dbf") 
cellsize = 0.1
xllcorner = -180
yllcorner = -36
xurcorner = 180
yurcorner = 36
system(paste0('/usr/local/bin/saga_cmd -c=48 grid_gridding 0 -INPUT \"ne_10m_admin_0_countries.shp\" -FIELD \"NAME_INT\" -GRID \"countries_10km.sgrd\" -GRID_TYPE 0 -TARGET_DEFINITION 0 -TARGET_USER_SIZE ', cellsize, ' -TARGET_USER_XMIN ', xllcorner+cellsize/2,' -TARGET_USER_XMAX ', xurcorner-cellsize/2, ' -TARGET_USER_YMIN ', yllcorner+cellsize/2,' -TARGET_USER_YMAX ', yurcorner-cellsize/2))
system(paste0(gdalwarp, ' countries_10km.sdat countries_10km.tif -r \"near\" -tr 0.1 0.1 -te -180 -36 180 36 -co \"COMPRESS=DEFLATE\"'))
## Peatlands Indonesia:
system("7za e Indonesia_peatlands.zip")
system(paste0('/usr/local/bin/saga_cmd -c=48 grid_gridding 0 -INPUT \"Indonesia_peatlands.shp\" -FIELD \"HECTARES\" -GRID \"peatlands_10km.sgrd\" -GRID_TYPE 0 -TARGET_DEFINITION 0 -TARGET_USER_SIZE ', cellsize, ' -TARGET_USER_XMIN ', xllcorner+cellsize/2,' -TARGET_USER_XMAX ', xurcorner-cellsize/2, ' -TARGET_USER_YMIN ', yllcorner+cellsize/2,' -TARGET_USER_YMAX ', yurcorner-cellsize/2))
system(paste0(gdalwarp, ' peatlands_10km.sdat peatlands_10km.tif -r \"near\" -tr 0.1 0.1 -te -180 -36 180 36 -co \"COMPRESS=DEFLATE\"'))
plot(raster("peatlands_10km.tif"))

## horizon thickness:
ds <- get("stsize", envir = GSIF.opts)
ds <- rowMeans(data.frame(c(NA,ds),c(ds,NA)), na.rm=TRUE)
tif.10km = list.files(pattern="10km")
g10km <- raster::stack(tif.10km[grep(".tif", tif.10km)])
names(g10km)
g10km <- as(g10km, "SpatialGridDataFrame")
## Weighted average based on the thickness of horizon:
g10km$BLDFIE_M_1m_10km_ll <- round(rowSums(g10km@data[,paste0("BLDFIE_M_sl", 1:6, "_10km_ll")] * data.frame(lapply(ds[-7], rep, length=nrow(g10km))), na.rm=TRUE) / sum(ds[-7]))
g10km$ORCDRC_M_1m_10km_ll <- round(rowSums(g10km@data[,paste0("ORCDRC_M_sl", 1:6, "_10km_ll")] * data.frame(lapply(ds[-7], rep, length=nrow(g10km))), na.rm=TRUE) / sum(ds[-7]))
g10km$CRFVOL_M_1m_10km_ll <- round(rowSums(g10km@data[,paste0("CRFVOL_M_sl", 1:6, "_10km_ll")] * data.frame(lapply(ds[-7], rep, length=nrow(g10km))), na.rm=TRUE) / sum(ds[-7]))
g10km$ORCDRC_M_2m_10km_ll <- round(rowSums(g10km@data[,c("ORCDRC_M_sl6_10km_ll","ORCDRC_M_sl7_10km_ll")], na.rm=TRUE)/2)
g10km$BLDFIE_M_2m_10km_ll <- round(rowSums(g10km@data[,c("BLDFIE_M_sl6_10km_ll","BLDFIE_M_sl7_10km_ll")], na.rm=TRUE)/2)
g10km$CRFVOL_M_2m_10km_ll <- round(rowSums(g10km@data[,c("CRFVOL_M_sl6_10km_ll","CRFVOL_M_sl7_10km_ll")], na.rm=TRUE)/2)
plot(raster(g10km["BLDFIE_M_sl1_10km_ll"]), col=SAGA_pal[[1]])
plot(raster(g10km["BLDFIE_M_2m_10km_ll"]), col=SAGA_pal[[1]])
g10km <- as(g10km, "SpatialPixelsDataFrame")
g10km$HISTPR_10km <- readGDAL("HISTPR_10km.tif")$band1[g10km@grid.index]
#g10km$Country <- readGDAL("countries_10km.sdat")$band1[g10km@grid.index]
country.df = data.frame(Country=1:length(levels(countries.dbf[["dbf"]]$NAME)), NAME=levels(countries.dbf[["dbf"]]$NAME))
g10km$Country_NAME <- plyr::join(data.frame(Country=g10km$countries_10km), country.df, type="left")$NAME
#spplot(g10km["Country_NAME"])
summary(!is.na(g10km$LMKGLC_10km))
summary(!is.na(g10km$OCSTHA_2m_10km))
g10km <- g10km[!is.na(g10km$LMKGLC_10km),]
plot(raster(g10km["BLDFIE_M_sl1_10km_ll"]), col=SAGA_pal[[1]])
plot(raster(g10km["HISTPR_10km"]), col=SAGA_pal[[1]])
plot(raster(g10km["BLDFIE_M_1m_10km_ll"]), col=SAGA_pal[[1]])
plot(log1p(raster(g10km["OCSTHA_1m_10km"])), col=SAGA_pal[[1]], zlim=c(0,8))
plot(log1p(raster(g10km["OCSTHA_2m_10km"])), col=SAGA_pal[[1]], zlim=c(0,8))
plot(log1p(raster(g10km["ORCDRC_M_1m_10km_ll"])), col=SAGA_pal[[1]])

## UPPER / LOWER UNCERTAINTY ESTIMATES:
OCS_1m <- GSIF::OCSKGM(ORCDRC=g10km$ORCDRC_M_1m_10km_ll, BLD=g10km$BLDFIE_M_1m_10km_ll, CRFVOL=g10km$CRFVOL_M_1m_10km_ll, HSIZE=100, ORCDRC.sd=15, BLD.sd=170) ## (expm1(log1p(g10km$ORCDRC_M_1m_10km_ll)+0.6)-expm1(log1p(g10km$ORCDRC_M_1m_10km_ll)-0.6))/2
OCS_2m <- GSIF::OCSKGM(ORCDRC=g10km$ORCDRC_M_2m_10km_ll, BLD=g10km$BLDFIE_M_2m_10km_ll, CRFVOL=g10km$CRFVOL_M_2m_10km_ll, HSIZE=100, ORCDRC.sd=15, BLD.sd=170)
g10km$OCSTHA_1m_10km_UPPER <- round(g10km$OCSTHA_1m_10km + attr(OCS_1m, "measurementError")*10)
g10km$OCSTHA_1m_10km_LOWER <- round(g10km$OCSTHA_1m_10km - attr(OCS_1m, "measurementError")*10)
g10km$OCSTHA_1m_10km_LOWER <- round(ifelse(g10km$OCSTHA_1m_10km_LOWER<0, 0, g10km$OCSTHA_1m_10km_LOWER))
g10km$OCSTHA_2m_10km_UPPER <- round(g10km$OCSTHA_2m_10km + attr(OCS_2m, "measurementError")*10)
g10km$OCSTHA_2m_10km_LOWER <- round(g10km$OCSTHA_2m_10km - attr(OCS_2m, "measurementError")*10)
g10km$OCSTHA_2m_10km_LOWER <- round(ifelse(g10km$OCSTHA_2m_10km_LOWER<0, 0, g10km$OCSTHA_2m_10km_LOWER))
## test it:
g10km@data[119000,c("OCSTHA_1m_10km_LOWER","OCSTHA_1m_10km","OCSTHA_1m_10km_UPPER")]
g10km@data[which(g10km$OCSTHA_1m_10km>2200)[1],c("OCSTHA_1m_10km_LOWER","OCSTHA_1m_10km","OCSTHA_1m_10km_UPPER")]
save.image()

g10km.pol <- grid2poly(g10km["LMKGLC_10km"]) ## Takes ca 10 mins!
library(geosphere)
## Calculate area in ha for each pixel in latlon (run in parallel):
getArea <- function(x,pol){geosphere::areaPolygon(as(pol[x,], "SpatialPolygons"))/1e4}
##area in ha
getArea(2,g10km.pol)
AREA <- unlist(parallel::mclapply( 1:length(g10km.pol), getArea, pol=g10km.pol, mc.cores=26)) ## memory demanding!
#g10km$AREA <- sapply(1:length(g10km.pol), function(x){geosphere::areaPolygon(as(g10km.pol[x,], "SpatialPolygons"))})/1e4
g10km$AREA <- AREA
summary(g10km$AREA)

g10km.df = as.data.frame(g10km[,c("OCSTHA_1m_10km","OCSTHA_2m_10km","HISTPR_10km","L05GLC_10km","BLDFIE_M_1m_10km_ll","BLDFIE_M_2m_10km_ll","ORCDRC_M_1m_10km_ll","ORCDRC_M_2m_10km_ll","CRFVOL_M_1m_10km_ll","CRFVOL_M_2m_10km_ll","OCSTHA_1m_10km_LOWER","OCSTHA_1m_10km_UPPER","OCSTHA_2m_10km_LOWER","OCSTHA_2m_10km_UPPER","AREA","Country_NAME","peatlands_10km")])
str(g10km.df)
summary(g10km.df$Country_NAME)[1:20]
unlink("TROP_grid10km.csv.gz")
write.csv(g10km.df, file="TROP_grid10km.csv")
gzip("TROP_grid10km.csv")
## Kalimantan:
kal = which(g10km.df$s1>110.6 & g10km.df$s1<110.8 & g10km.df$s2> -2.9 & g10km.df$s2 < -2.7)
g10km.df[kal,c("OCSTHA_1m_10km_LOWER","OCSTHA_1m_10km","OCSTHA_1m_10km_UPPER","Country_NAME")]
## Total estimate of OCS for 0-1 m and 1-2 m (total sum):
sum(g10km.df$OCSTHA_1m_10km * g10km.df$AREA * 1e6, na.rm = TRUE)/1e15
sum(g10km.df$OCSTHA_2m_10km * g10km.df$AREA * 1e6, na.rm = TRUE)/1e15
## estimate of the total OCS for Indonesia:
ind.sel = which(g10km.df$Country_NAME=="Indonesia")
sum(g10km.df$OCSTHA_1m_10km[ind.sel] * g10km.df$AREA[ind.sel] * 1e6, na.rm = TRUE)/1e15
## 104.911
sum(g10km.df$OCSTHA_2m_10km[ind.sel] * g10km.df$AREA[ind.sel] * 1e6, na.rm = TRUE)/1e15
## 50.34261
## estimate of the total OCS for Peatlands:
pea.sel = which(!is.na(g10km.df$peatlands_10km))
sum(g10km.df$OCSTHA_1m_10km[pea.sel] * g10km.df$AREA[pea.sel] * 1e6, na.rm = TRUE)/1e15
## 15.12484
sum(g10km.df$OCSTHA_2m_10km[pea.sel] * g10km.df$AREA[pea.sel] * 1e6, na.rm = TRUE)/1e15
## 6.982348
## Peatlands in Indonesia:
(sum(!is.na(g10km.df$peatlands_10km), na.rm=TRUE)/sum(g10km.df$Country_NAME=="Indonesia", na.rm=TRUE))*100
## DERIVE Summary stats per country:
g10km.df$OCS_1m_Pg_upper = g10km.df$OCSTHA_1m_10km_UPPER*g10km.df$AREA*1e6/1e15
g10km.df$OCS_1m_Pg_lower = g10km.df$OCSTHA_1m_10km_LOWER*g10km.df$AREA*1e6/1e15
g10km.df$OCS_1m_Pg = g10km.df$OCSTHA_1m_10km*g10km.df$AREA*1e6/1e15
registerDoMC(36)
SOC_agg <- ddply(g10km.df, .(Country_NAME), summarize, Total_OCS_1m_Pg=round(sum(OCSTHA_1m_10km*AREA*1e6,na.rm = TRUE)/1e15,1), Total_OCS_2m_Pg=round(sum(OCSTHA_2m_10km*AREA*1e6,na.rm = TRUE)/1e15,1), Total_OCS_1m_Pg_lower=round(sum(OCS_1m_Pg_lower, na.rm=TRUE)), Total_OCS_1m_Pg_upper=round(sum(OCS_1m_Pg_upper, na.rm=TRUE)), Total_OCS_1m_N=sum(!is.na(OCSTHA_1m_10km)), Total_AREA=sum(AREA,na.rm=TRUE)/1e6, .parallel = TRUE)
## sqrt(mean((OCS_1m_Pg_upper-OCS_1m_Pg_lower)^2, na.rm=TRUE))
closeAllConnections(); gc()
str(SOC_agg)
write.csv(SOC_agg[,c(1:3,6,7)], "Summary_OCS_per_country.csv")
## https://www.r-bloggers.com/interval-estimation-of-the-population-mean/
SOC_agg$Total_OCS_1m_Pg_lower=NA
SOC_agg$Total_OCS_1m_Pg_upper=NA
for(i in 1:nrow(SOC_agg)){
  x = zsum.test(mean.x=SOC_agg$Total_OCS_1m_Pg[i], sigma.x = SOC_agg$Total_OCS_1m_Pg_sigma[i], n.x = SOC_agg$Total_OCS_1m_Pg_N[i], conf.level = 0.95)
  SOC_agg$Total_OCS_1m_Pg_lower[i] = x$$conf.int[1]
  SOC_agg$Total_OCS_1m_Pg_upper[i] = x$$conf.int[2]
}

## plot in Google Earth:
setwd("/data/CIFOR")
#source("plotKML.GDALobj.R")
#source("legend.bar.R")
#r1 = raster("TROP_OCSTHA_1m_1km_ll.tif")
#r2 = raster("TROP_OCSTHA_2m_1km_ll.tif")
#r3 = raster("HISTPR_1km_ll.tif")
#hist(log1p(sampleRandom(r1, 1e3)))
#setwd("/data/CIFOR/OCSTHA_2m")
#beginCluster()
#r <- clusterR(r2, fun=log1p, filename="TROP_OCSTHA_2m_1km_ll_log1p.tif", options=c("COMPRESS=DEFLATE"))
#endCluster()
#writeRaster(log1p(r), "TROP_OCSTHA_2m_1km_ll_log1p.tif")
#obj = GDALinfo("TROP_OCSTHA_2m_1km_ll_log1p.tif")
#plotKML.GDALobj(obj, file.name="TROP_log_OCSTHA_2m_1km.kml", block.x=5, z.lim=c(0,7.2), colour_scale = SAGA_pal[[1]], CRS="+proj=longlat +datum=WGS84", plot.legend=FALSE) # z.lim=c(0,1200)

#setwd("/data/CIFOR/OCSTHA_1m")
#beginCluster()
#r <- clusterR(r1, fun=log1p, filename="TROP_OCSTHA_1m_1km_ll_log1p.tif", options=c("COMPRESS=DEFLATE"))
#endCluster()
#obj = GDALinfo("TROP_OCSTHA_1m_1km_ll_log1p.tif")
#plotKML.GDALobj(obj, file.name="TROP_log_OCSTHA_1m_1km.kml", block.x=5, z.lim=c(0,7.2), colour_scale = SAGA_pal[[1]], CRS="+proj=longlat +datum=WGS84", plot.legend=FALSE)

#setwd("/data/CIFOR/HISTPROB")
#obj = GDALinfo("HISTPR_1km_ll.tif")
#plotKML.GDALobj(obj, file.name="TROP_HISTPR_1km.kml", block.x=5, z.lim=c(0,40), colour_scale = SAGA_pal[["SG_COLORS_YELLOW_BLUE"]], CRS="+proj=longlat +datum=WGS84", plot.legend=FALSE)
#setwd("/data/CIFOR")

## -tr 9000 9000 -s_srs \"+proj=longlat +datum=WGS84\" -t_srs \"', rob, '\" -co \"COMPRESS=DEFLATE\" -dstnodata -9999')) 
te <- as.vector(extent(raster("OCSTHA_1m_10km.tif")))
system(paste0(gdalwarp, ' X:/HWSD/HWSDa_OC_Dens_Top_5min.rst OCSTHA_1m_HWSDa.tif -tr 0.1 0.1 -co \"COMPRESS=DEFLATE\" -te ', paste(te[c(1,3,2,4)], collapse=" "))) 
##  -tr 9000 9000 -s_srs \"+proj=longlat +datum=WGS84\" -te ', paste(te[c(1,3,2,4)], collapse=" "),' -t_srs \"', rob, '\" -co \"COMPRESS=DEFLATE\"'))
system(paste0(gdalwarp, ' X:/HWSD/HWSDa_OC_Dens_Sub_5min.rst OCSTHA_1m_HWSDb.tif -tr 0.1 0.1 -co \"COMPRESS=DEFLATE\" -te ', paste(te[c(1,3,2,4)], collapse=" ")))

trop <- stack(c("OCSTHA_1m_10km.tif","OCSTHA_1m_HWSDa.tif","OCSTHA_1m_HWSDb.tif"))
trop <- as(as(trop, "SpatialGridDataFrame"), "SpatialPixelsDataFrame")
trop$SOCS_old <- trop$OCSTHA_1m_HWSDa+trop$OCSTHA_1m_HWSDb
names(trop)
rn = c(10,1200) ## quantile(c(trop$OCSTHA_1m_9km, trop$SOCS_old), c(.01, .99), na.rm=TRUE)
rx = rev(as.character(round(c(round(rn[1], 0), NA, round(mean(rn), 0), NA, round(rn[2], 0)), 2)))
trop$SOCS_oldf <- ifelse(trop$SOCS_old<rn[1], rn[1], ifelse(trop$SOCS_old>rn[2], rn[2], trop$SOCS_old))
trop$OCSTHA_1m_10km <- ifelse(trop$OCSTHA_1m_10km==0, NA, trop$OCSTHA_1m_10km)
trop$SOCS_SGf <- ifelse(trop$OCSTHA_1m_10km<rn[1], rn[1], ifelse(trop$OCSTHA_1m_10km>rn[2], rn[2], trop$OCSTHA_1m_10km))

require(maptools)
require(maps)
library(rgeos)
country <- map('world', plot=FALSE, fill=TRUE)
IDs <- sapply(strsplit(country$names, ":"), function(x) x[1])
country = as(map2SpatialPolygons(country, IDs=IDs), "SpatialLines")
b_poly <- as(extent(c(-180,180,-36,36)), "SpatialPolygons")
country = gIntersection(country, b_poly, byid = T)
proj4string(country) = "+proj=longlat +datum=WGS84"
#country <- spTransform(country, CRS(rob))

png(file="Fig_SOCS_comparison.png", res=100, width=1200, height=1200*2*(36+36)/180/2)
#spplot(trop, col.regions=SAGA_pal[[1]])
par(mfrow=c(2,1))
par(mai=c(0,0,0,0), oma=c(0,0,0,0),xaxs='i', yaxs='i')
image(log1p(raster(trop["SOCS_oldf"])), col=SAGA_pal[[1]], zlim=log1p(rn), main="", axes=FALSE, xlab="", ylab="") # , cex.lab=.7, cex.axis=.7
lines(country)
legend("left", rx, fill=rev(SAGA_pal[[1]][c(1,5,10,15,20)]), horiz=FALSE, cex=.8)
image(log1p(raster(trop["SOCS_SGf"])), col=SAGA_pal[[1]], zlim=log1p(rn), main="", axes=FALSE, xlab="", ylab="")
lines(country)
legend("left", rx, fill=rev(SAGA_pal[[1]][c(1,5,10,15,20)]), horiz=FALSE, cex=.8)
dev.off()

save.image()
## Scatter plot histograms:
df.s <- trop@data[sample.int(length(trop),20000),]
with(df.s, scatter.hist(SOCS_old,OCSTHA_1m_10km, xlab="HWSD", ylab="SoilGrids", pch=19, col=alpha("lightblue", 0.6), cex=1.5))
