NetcdfOutput_OMI_MP <- function(df,varname){
  
  # -- Path here to save the netcdf file
  path <- paste0('./Output_',Sys.Date())
  
  # -- OMI file name : let's build the standard name of your future file
  area            <- 'bs'             # or med or nws, ...
  short_omi_name  <- 'oc'             # 
  first_occurence <- '20110101'       # yyyymmdd
  prod_time       <- paste0('P',gsub("-",'',as.character(Sys.Date())))      # P + yourdate yyyymmdd
  other_info      <- varname          # ohc case ...
  
  # -- TIME info
#  TIMEdf <- data.frame(origin   = as.Date('1950-01-01 00:00:00'),
#                       calendar = 'gregorian',
#                       units    = 'days since 1950-01-01 00:00:00',
#                       name     = 'time')
  
  TIMEdf <- list(origin   = as.Date('1950-01-01 00:00:00'),
                       calendar = 'gregorian',
                       units    = 'days since 1950-01-01 00:00:00',
                       name     = 'time')

  # -- VAR infos
  VOCdf   <- list(long_name     = "Oxygen Content",
                       units         = 'mol/m^2',
                       name          = 'oxygen_content',
                       standard_name = 'oxygen_content',
                       FillValue     = -9999.0,
                       Comment       = 'Vertically integrated oxygen concentration',
                       minsc         = 0, 
                       maxsc         = 40,
                       ncname        = 'oxygen_inventory')
  #rownames(VOCdf)<-"VOC"
  
  Z20df   <- list(long_name     = "Oxygen Penetration Depth",
                       units         = 'm',
                       name          = 'oxycline_depth',
                       standard_name = 'oxycline_depth',
                       FillValue     = -9999.0,
                       Comment       = 'Depth at which [O2]<20µM', 
                       minsc         = 170, 
                       maxsc         = 0,
                       ncname        = 'oxygen_penetration_depth')
  #rownames(Z20df)<-"Z20"
  
  R20df   <- list(long_name     = "Oxygen Penetration Density",
                        units         = 'kg/m3',
                        name          = 'oxycline_density',
                        standard_name = 'oxycline_density',
                        FillValue     = -9999.0,
                        Comment       = 'Potential density anomaly at which [O2]<20µM',
                        minsc         = 16.5, 
                        maxsc         = 14.5,
                        ncname        = 'oxygen_penetration_density')
  
  
  allvardf <- list(VOC=VOCdf,Z20=Z20df,R20=R20df)

  vardf <- allvardf[[varname]]
  
  ### ### ### ### #### 
  # Data Preparation #
  ### ### ### ### #### 

  df$juld <- round(df$juld)
  df      <- subset(df,select = c("juld","lon","lat","Platform",varname))
  colnames(df)[which(colnames(df)==varname)]<-"value"
  
  timevals <- seq(min(df$juld),max(df$juld))

  # -- Create platform list
  Platformlist <- unique(subset(df, !is.nan(value),select='Platform'))
  
  longdf <- data.frame(time = timevals, 
                       mean = NA,
                       stde = NA)
  
  for (p in Platformlist$Platform) {
    print(p)
    platdf <- subset(df,Platform==p)
    longdf[match(platdf$juld ,longdf$time), p ] <- platdf$value
  }

  timespan <- 90 # days for a smoothed average and std error estimates  
  ##########################################
  # !!! Different option for stde definition !!! 
  # Pick your choice and comment the rest
  ##########################################
  # 1. simplest standard error on Mean estimate. -> problem due to sd estimation from very few floats (eg. 1)
  errorfromneighb1 <- function(neihgbdf) {
      sd( neihgbdf$value,na.rm = TRUE) / sqrt(sum(!is.na(neihgbdf$value) ))
  }
  
  # 2. Second option, the standard deviation used for standard error on mean estimate is estimated from the global datasets (not only the local one)
  fullsd <- sd( df$value,na.rm = TRUE)
  errorfromneighb2 <- function(neihgbdf) {
  fullsd  / sqrt(sum(!is.na(neihgbdf$value) ))
  }
  
  for (d in longdf$time){
    if ( (d-min(longdf$time))<timespan/2 | (max(longdf$time)-d< timespan/2) ){longdf[which(longdf$time ==d), c('mean','stde')]<-NA}
    else{
    neihgbdf  <-  subset(df, abs(juld-d)<timespan/2)
    longdf[which(longdf$time ==d),'mean'] <- mean( neihgbdf$value,na.rm = TRUE)
    longdf[which(longdf$time ==d),'stde'] <- errorfromneighb2(neihgbdf)
      }
  }

  ##########
  # Figure #
  ##########
  source("OMI_figure.R")
  figname <- paste0(area,'_omi_',short_omi_name,'_area_averaged_',vardf$ncname,'_',first_occurence,'_',prod_time,'.pdf')
  OMI_figure(longdf, TIMEdf, vardf, figname)
  
  ###############
  # NC Creation #
  ###############
  ncfname <- paste0(area,'_omi_',short_omi_name,'_area_averaged_',vardf$ncname,'_',first_occurence,'_',prod_time,'.nc')
  
  # -- Create the dimensions of the netcdf file
  timedim <- ncdim_def( as.character(TIMEdf$name)  ,
                        as.character(TIMEdf$units) ,
                        vals  = timevals           ,
                        unlim = TRUE)
  
  nvdim   <- ncdim_def( name = "nv",
                        units = "",
                        vals=1:2,
                        create_dimvar = FALSE)
  
  # -- Create vars
  count<-1
  defVar<-list()
  
  for (p in Platformlist$Platform) {
    tmp<- ncvar_def(name     = paste0(vardf$name,'_',p),
              units    = as.character(vardf$units),
              dim      = list(timedim),
              missval  = vardf$FillValue, 
              longname = vardf$long_name)    
      
      defVar[[count]] <- tmp
      count<- count+1
    }
  ###
   tmp<- ncvar_def(name     = paste0(vardf$name,'_','mean'),
                      units    = as.character(vardf$units),
                      dim      = list(timedim),
                      missval  = vardf$FillValue, 
                      longname = as.character(vardf$long_name))    
   defVar[[count]] <- tmp
   count<- count+1
  ###
   tmp<- ncvar_def(name     = paste0(vardf$name,'_','std'),
                   units    = as.character(vardf$units),
                   dim      = list(timedim),
                   missval  = vardf$FillValue, 
                   longname = as.character(vardf$long_name))    
   defVar[[count]] <- tmp
   count<- count+1
  ###
   tmp  <- ncvar_def(name = "time_bnds",
                        "",
                        list(nvdim,timedim ))
   defVar[[count]] <- tmp
   count<- count+1
  
  # -- Create netcdf file  
  if (file.exists(ncfname)) file.remove(ncfname)
  ncout   <- nc_create(ncfname,defVar,force_v4=T)

  ## Writing Variables values
  for (p in Platformlist$Platform) {  
    ncvar_put(ncout,paste0(vardf$name,'_',p),replace(longdf[,p],(is.na(longdf[,p]) |  is.nan(longdf[,p])|is.infinite(longdf[,p])) ,vardf$FillValue))
  }
  ncvar_put(ncout,paste0(vardf$name,'_','std'), replace( longdf[,'stde'] , (is.na(longdf[,'stde']) |  is.nan(longdf[,'stde'])|is.infinite(longdf[,'stde'])) ,vardf$FillValue))
  ncvar_put(ncout,paste0(vardf$name,'_','mean'), longdf[,'mean'])
  ncvar_put(ncout,"time_bnds", matrix( data = c(timevals-timespan/2 , timevals+timespan/2), nrow = 2, byrow = TRUE) )

  #############
  # ATRIBUTES #
  #############
  
  # Variable Attributes 
  #  - time
  ncatt_put(ncout,"time","standard_name","time")
  ncatt_put(ncout,"time","unit",TIMEdf$units)
  ncatt_put(ncout,"time","axis",'T')
  ncatt_put(ncout,"time","calendar",TIMEdf$calendar)
  ncatt_put(ncout,"time","bounds","time_bnds")
  
    for (p in Platformlist$Platform) {  
      ncatt_put(ncout,paste0(vardf$name,'_',p), "comment"      , paste0( vardf$comment, ' as measured from ARGO ', p))
    }
    ncatt_put(ncout,paste0(vardf$name,'_','mean'), "comment"      , paste0( vardf$comment, ' ',timespan, ' days window average'))
    ncatt_put(ncout,paste0(vardf$name,'_','mean'), "cell_methods","time: mean")
    ncatt_put(ncout,paste0(vardf$name,'_','mean'), "ancillary_variables" , paste0( vardf$name,'_','std'))
    ncatt_put(ncout,paste0(vardf$name,'_','std'), "comment"       , paste0( vardf$comment, ' ',timespan, ' days window standard error'))
    ncatt_put(ncout,paste0(vardf$name,'_','std'), "standard_name" , paste0( vardf$name,'_','mean',' standard_error'   ))
    
#  Global Attributes
  ncatt_put(ncout,0,'title'       ,'Black Sea Oxygen Inventory' )# to be consistent with PIT
  ncatt_put(ncout,0,'institution' ,'ULiege')
  ncatt_put(ncout,0,'references'  ,'http://marine.copernicus.eu') #please do not change
  ncatt_put(ncout,0,'Conventions' ,'CF-1.7')
  ncatt_put(ncout,0,'credit'      ,'E.U. Copernicus Marine Service Information (CMEMS)' )#please do not change
  ncatt_put(ncout,0,'contact'     ,'servicedesk.cmems@mercator-ocean.eu'       )         #please do not change
  ncatt_put(ncout,0,'source'      ,'INSITU_BS_NRT_OBSERVATIONS_013_034')
  ncatt_put(ncout,0,'licence'     ,'http://marine.copernicus.eu/services-portfolio/service-commitments-and-licence/'  ) #please do not change
  ncatt_put(ncout,0,'product'     ,'BS_OMI_OC')
  ncatt_put(ncout,0,'dataset'     ,'bs_omi_oc')
  ncatt_put(ncout,0,'quality_information_document','http://marine.copernicus.eu/documents/QUID/CMEMS-OMI-QUID-BS-OC-TSERIES.pdf')
  ncatt_put(ncout,0,'product_user_manual'         ,'http://marine.copernicus.eu/documents/PUM/CMEMS-OMI-PUM-OC.pdf')
  ncatt_put(ncout,0,'area'                        ,'BS')
  ncatt_put(ncout,0,'comment'                     ,'Period : 2010-2018')
  nc_close(ncout)

################
# ANNUAL FILES #
################

  # # # # # # # # # # # 
  # Data Preparation  #
  # # # # # # # # # # # 
  
  dateorigin <- as.Date("1/1/1950", "%d/%m/%Y")
  firstyear <- 1955
  lastyear <- 2017
  
  yearMJD <- data.frame(year= seq(firstyear,lastyear))
  
  for (yearsi in (1:(lastyear-firstyear+1))){
    yearss <-yearMJD$year[yearsi]
    firstday  <- as.Date(paste0("01/01/", as.character(yearss)), "%d/%m/%Y") 
    yearMJD$beg[yearsi]  <- as.numeric(difftime(firstday, dateorigin, units = "days"))
    midday  <- as.Date(paste0("01/06/", as.character(yearss)), "%d/%m/%Y") 
    yearMJD$mid[yearsi]  <- as.numeric(difftime(midday, dateorigin, units = "days"))
    endDate  <- as.Date(paste0("31/12/", as.character(yearss)), "%d/%m/%Y") 
    yearMJD$end[yearsi]  <- as.numeric(difftime(endDate, dateorigin, units = "days"))
  }
  
  # LOAD INTERANNUAL TREND
  varsdfL<-rbind(
  data.frame(row.names="VOC", ymin=5,    ymax= 35,   yminl=8,    ymaxl= 35,   Fact= 1/1000 , Unit="mol m-2", YLAB= paste("Oxygen Inventory "  ,sep="")),       
  data.frame(row.names="R20", ymin=16.2, ymax= 14.6, yminl=16.3, ymaxl= 15.0, Fact= 1      , Unit="kg m-3" , YLAB= paste("Penetration density",sep="")),       
  data.frame(row.names="Z20", ymin=160,  ymax= 20,   yminl=170,  ymaxl= 70,   Fact=1       , Unit="m",       YLAB= paste("Penetration depth"  ,sep=""))      
  )

  DDir<-"/home/arthur/diva/BlackSea4diva/"
  fi<-paste(DDir,"data/",varname,"/detrending/",varname,".dat",sep="")
  totdata<-read.table(fi,col.names=c("lat","lon","Value","Month","Year","Weight"))
  totdata[,"Value"]<-totdata[,"Value"]*varsdfL[varname,"Fact"]
  totdata<-subset(totdata,Year>1900)   #### JUSTIFY THIS ####
  globalaverage<-mean(totdata$Value)
  
  fi<-paste(DDir,"results/",varname,"/detrend_L0pt8/trends2_00.dat",sep="")
  #  fi2<-paste(DDir,"results/",VAR,"/detrend_L0pt8/trends2_err.dat",sep="")
    
  trendi<-read.table(fi,colClasses=c("NULL",NA),col.names=c("bid","Trend"))*varsdfL[varname,"Fact"]
    # trendiE<-read.table(fi2,colClasses=c("NULL",NA,NA),col.names=c("bid","Trend","err"))*varsdfL[varname,"Fact"]
    
  trendi<-cbind(Year=seq(1923,2013),trendi)
  
  # get num of data 
  ni<-data.frame(table(totdata$Year))
  colnames(ni)<-c("Year","Nprofs")
  trendi<-merge(trendi,ni,all.x=TRUE) #
  trendi[,"Trend"]<-trendi[,"Trend"]+globalaverage
  trendi[,"VAR"]<-varname
    
  trendf<-trendi
  trendf[is.na(trendf$Nprofs),"Nprofs"]<-0
  
  Nprofmin <- 10
  yearmin <- 1954
  yearmax <- 2006
  trendfsub <-  subset(trendf,Nprofs>Nprofmin&Year>yearmin&VAR==varname&Year<yearmax)
  
  longdfannual <- data.frame(year        = yearMJD$year, 
                             time        = yearMJD$mid, 
                             beg         = yearMJD$beg,
                             end         = yearMJD$end,
                             Ship_casts  = NA,
                             Ship_casts_error = NA, 
                             Argos       = NA,
                             Argos_error = NA,
                             mean        = NA,
                             stde        = NA)
  
  longdfannual[match(trendfsub$Year ,yearMJD$year), "Ship_casts" ] <- trendfsub$Trend
  
  timespan<-365
  
  for (d in longdfannual$time){
    if ( (d-min(longdfannual$time))<timespan/2 | (max(longdfannual$time)-d< timespan/2) ){
      longdfannual[which(longdfannual$time ==d), c('Argos','Argos_error')]<-NA
      } else{
      neihgbdf  <-  subset(df, abs(juld-d)<timespan/2)
      longdfannual[which(longdfannual$time ==d),'Argos']       <- mean( neihgbdf$value,na.rm = TRUE)
      longdfannual[which(longdfannual$time ==d),'Argos_error'] <- errorfromneighb1(neihgbdf)
    }
  }
  
  longdfannual <- ddply(longdfannual,.(year), mutate,mean=mean(c(Argos,Ship_casts), na.rm=TRUE))
  
  # # # # # # # #
  # NC Creation #
  # # # # # # # #
  
  ncfname <- paste0(area,'_omi_',short_omi_name,'_area_averaged_',vardf$ncname,'_Annual_',first_occurence,'_',prod_time,'.nc')
  
  # -- Create the dimensions of the netcdf file
  timedim <- ncdim_def( as.character(TIMEdf$name)  ,
                        as.character(TIMEdf$units) ,
                        vals  = longdfannual$time     ,
                        unlim = TRUE)
  
  nvdim   <- ncdim_def( name = "nv",
                        units = "",
                        vals=1:2,
                        create_dimvar = FALSE)
  
  # -- Create vars
  count<-1
  defVar<-list()

  ###
  tmp<- ncvar_def(name     = paste0(vardf$name,'_','Argos'),
                  units    = as.character(vardf$units),
                  dim      = list(timedim),
                  missval  = vardf$FillValue, 
                  longname = as.character(vardf$long_name))    
  defVar[[count]] <- tmp
  count<- count+1
  ###
  tmp<- ncvar_def(name     = paste0(vardf$name,'_','Argos_error'),
                  units    = as.character(vardf$units),
                  dim      = list(timedim),
                  missval  = vardf$FillValue, 
                  longname = as.character(vardf$long_name))    
  defVar[[count]] <- tmp
  count<- count+1
  ###
  tmp<- ncvar_def(name     = paste0(vardf$name,'_','Ship_casts'),
                  units    = as.character(vardf$units),
                  dim      = list(timedim),
                  missval  = vardf$FillValue, 
                  longname = as.character(vardf$long_name))    
  defVar[[count]] <- tmp
  count<- count+1
  ###
  tmp<- ncvar_def(name     = paste0(vardf$name,'_','Ship_casts_error'),
                  units    = as.character(vardf$units),
                  dim      = list(timedim),
                  missval  = vardf$FillValue, 
                  longname = as.character(vardf$long_name))    
  defVar[[count]] <- tmp
  count<- count+1
  ###
  tmp<- ncvar_def(name     = vardf$name,
                  units    = as.character(vardf$units),
                  dim      = list(timedim),
                  missval  = vardf$FillValue, 
                  longname = as.character(vardf$long_name))    
  defVar[[count]] <- tmp
  count<- count+1
  ###
  tmp<- ncvar_def(name     = paste0(vardf$name,'_','error'),
                  units    = as.character(vardf$units),
                  dim      = list(timedim),
                  missval  = vardf$FillValue, 
                  longname = as.character(vardf$long_name))    
  defVar[[count]] <- tmp
  count<- count+1
  ###
  tmp  <- ncvar_def(name = "time_bnds",
                    "",
                    list(nvdim,timedim ))
  defVar[[count]] <- tmp
  count<- count+1
  
  # -- Create netcdf file  
  if (file.exists(ncfname)) file.remove(ncfname)
  ncout   <- nc_create(ncfname,defVar,force_v4=T)
  
  ## Writing Variables values
  for (p in c("Argos","Argos_error","Ship_casts","Ship_casts_error")) {  
    ncvar_put(ncout,paste0(vardf$name,'_',p),
              replace(longdfannual[,p],(is.na(longdfannual[,p]) |  is.nan(longdfannual[,p])|is.infinite(longdfannual[,p])) ,vardf$FillValue))
  }
  ncvar_put(ncout,vardf$name, longdfannual[,'mean'])
  ncvar_put(ncout,paste0(vardf$name,'_','error'), replace(
    longdfannual[,'stde'] , (is.na(longdfannual[,'stde']) |  is.nan(longdfannual[,'stde'])|is.infinite(longdfannual[,'stde'])) ,vardf$FillValue))
  
  ncvar_put(ncout,"time_bnds", matrix( data = c(longdfannual$beg , longdfannual$end), nrow = 2, byrow = TRUE) )
  
  
  # # # # # # #
  # ATRIBUTES #
  # # # # # # #
  
  # Variable Attributes 
  #  - time
  ncatt_put(ncout,"time","standard_name","time")
  ncatt_put(ncout,"time","unit",TIMEdf$units)
  ncatt_put(ncout,"time","axis",'T')
  ncatt_put(ncout,"time","calendar",TIMEdf$calendar)
  ncatt_put(ncout,"time","bounds","time_bnds")
  
#  ncatt_put(ncout,paste0(vardf$name,'_','mean'), "comment"      , paste0( vardf$comment, ' ',timespan, ' days window average'))
#  ncatt_put(ncout,paste0(vardf$name,'_','mean'), "cell_methods","time: mean")
#  ncatt_put(ncout,paste0(vardf$name,'_','std'), "comment"       , paste0( vardf$comment, ' ',timespan, ' days window standard error'))
  
  
  #  Global Attributes
  ncatt_put(ncout,0,'title'       ,'Black Sea Oxygen Inventory' )# to be consistent with PIT
  ncatt_put(ncout,0,'institution' ,'ULiege')
  ncatt_put(ncout,0,'references'  ,'http://marine.copernicus.eu') #please do not change
  ncatt_put(ncout,0,'Conventions' ,'CF-1.7')
  ncatt_put(ncout,0,'credit'      ,'E.U. Copernicus Marine Service Information (CMEMS)' )#please do not change
  ncatt_put(ncout,0,'contact'     ,'servicedesk.cmems@mercator-ocean.eu'       )         #please do not change
  ncatt_put(ncout,0,'source'      ,'INSITU_BS_NRT_OBSERVATIONS_013_034')
  ncatt_put(ncout,0,'licence'     ,'http://marine.copernicus.eu/services-portfolio/service-commitments-and-licence/'  ) #please do not change
  ncatt_put(ncout,0,'product'     ,'BS_OMI_OC')
  ncatt_put(ncout,0,'dataset'     ,'bs_omi_oc')
  ncatt_put(ncout,0,'quality_information_document','http://marine.copernicus.eu/documents/QUID/CMEMS-OMI-QUID-BS-OC-TSERIES.pdf')
  ncatt_put(ncout,0,'product_user_manual'         ,'http://marine.copernicus.eu/documents/PUM/CMEMS-OMI-PUM-OC.pdf')
  ncatt_put(ncout,0,'area'                        ,'BS')
  ncatt_put(ncout,0,'comment'                     ,'Period : 2010-2018')
  nc_close(ncout)
}




