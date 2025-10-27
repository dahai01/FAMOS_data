
//this code is based on the "skimming" code in the tdm23, 
// with more tod (pm, nt) and more skims ( like truck skims) this was needed for preparing the data request by Tredis. 
macro "run"

    scen_dir = "D:\\Projects\\allston\\tdm23\\outputs\\2050\\bld_new_lu\\bld25_newlu\\" 
    scen_dir = "D:\\Projects\\allston\\tdm23\\outputs\\2050\\nb\\nb_step16\\" 
    //scen_dir ="D:\\Projects\\allston\\tdm23\\outputs\\AssignTransitOnly\\bld2050_2\\" //update me 
    inpt_dir ="D:\\Projects\\allston\\tdm23\\inputs" //update me 
    //
    hwy_dbd = scen_dir + "_networks\\LinksNodes.dbd"
    trn_rts =  scen_dir + "_networks\\RoutesStops.rts"
    out_dir = scen_dir + "temp\\"

    log_level = 1
    vot=.25
    drv_time_fact=10
 

   
   min_fare = 3.39
   base_fare = 3.44
   dist_fare = 0.51
   time_fare = 0.2
   fare_wt_adj = 1 
   rs_fare_ls = {3.39,3.44,0.51,0.2,1}   //min_fare = 3.39, base_fare = 3.44, dist_fare = 0.51, time_fare = 0.2, fare_wt_adj = 1


    mode_table = inpt_dir + "\\params\\transit_modes_2050_20231231.bin"
   mode_table_tw = inpt_dir + "\\params\\transit_modes_2050_20231231_cr1.5.bin"
    transfer_file = inpt_dir + "\\params\\transfer_fare_20231221.bin"
    zonal_fares = inpt_dir + "\\params\\zonal_fares_20231218.mtx"
    path_thr = {  {"MaxTripCost",180},
                  {"MaxModalTotal",180},
                  {"MaxTransfers",6},
                  {"MaxInitialWait",60},
                  {"MaxTransferWait",45},
                  {"MaxAccessWalk",25},
                  {"MaxEgressWalk",25},
                  {"MaxDriveTime",60},
                  {"MaxParkToStopTime",10},
                  {"MinParkingCapacity",25}}

    penalties = {{"TransferPenalty - walk - pk",12},
                     {"TransferPenalty - walk - np",10},
                     {"TransferPenalty - auto - pk",18},
                     {"TransferPenalty - auto - np",20},
                     {"TransferPenalty - lx",99}}
            
    global_wgts ={ {"WalkTimeFactor",3},
                     {"Fare",1},
                     {"DriveTimeFactor",10}}

    mode_wgts = { {"Time","ivtt_weight"},
                  {"Dwelling","ivtt_weight"},
                  {"InitialWait","iwait_weight"},
                  {"ParkToStopTime","max_pnr_walk"},
                  {"TransferWait","xwait_weight"}}

    path_comb = { {"CombinationFactor",1},
                        {"WalkFactor",0},
                        {"DriveFactor",0.1}}
    vot = 0.25
    pnr = { {"Alpha",1.5},
            {"Beta",2},
            {"MaxFactor",25},
            {"PnROccupancy",1.2},
            {"RMSE_Threshold",10}}

    parkUsageTable =scen_dir + "_skim\\pt_park_usage_am.bin"

   Transit_net_var = {mode_table ,mode_table_tw,transfer_file,zonal_fares ,path_thr ,penalties  ,global_wgts,mode_wgts ,path_comb ,vot ,pnr, parkUsageTable}






      runmacro ("Skim Highway",scen_dir,hwy_dbd,out_dir,log_level,rs_fare_ls)
      runmacro ("Skim PK NP Transit Walk",scen_dir,out_dir,trn_rts,Transit_net_var)
      runmacro ("Skim PK NP Transit Auto",scen_dir,out_dir,trn_rts,vot,drv_time_fact,Transit_net_var)
endmacro


macro "Skim Highway"  (scen_dir,hwy_dbd,out_dir,log_level,rs_fare_ls)
// Helper function to skim AM and MD highway network
   
   /*
    hwy_dbd              = Args.[Highway]  
    out_dir              = Args.OutputFolder    
    log_level            = Args.loglevel  
   

   if Args.DryRun = 1 then Return(1)
    ok = 1

     */

    for tod in {"am","md","pm","nt"} do //{"am","md","pm","nt"}
      for mode in {"da","sr","mtrk","htrk"} do
        // hwy_net = Args.("Highway Net - " + tod)
        hwy_net = scen_dir + "_networks\\hwy_"+tod+".net"
        hwy_skim = scen_dir + "temp\\hwy_"+mode+"_"+tod+".mtx"
         //hwy_skim = runmacro("get_highway_mode_skim_file", out_dir, tod, mode)
         ok = runmacro("skim_highway_mode", hwy_dbd, hwy_net, hwy_skim, mode, tod)
         ok = runmacro("rename_skim_cores", hwy_skim, mode)
      end

      // combine da and sr skims
      comb_mat = runmacro("combine_mode_skims", out_dir, tod,scen_dir)

      // add rs fare core
      if (comb_mat <> null) then ok = runmacro("calc_rs_fare", rs_fare_ls, comb_mat)
      else ok = 0

      //runmacro("calc_rs_fare", rs_fare_ls, comb_mat)

    end
    
    // delete single skims
    
      for tod in {"am","md","pm","nt"} do //{"am","md","pm","nt"}
         for mode in {"da","sr","mtrk","htrk"} do
            hwy_skim = scen_dir + "temp\\hwy_"+mode+"_"+tod+".mtx"
            //hwy_skim = runmacro("get_highway_mode_skim_file", out_dir, tod, mode)
            DeleteFile(hwy_skim)
         end
      end
    
    

    return(ok)

endmacro

macro "skim_highway_mode" (hwy_dbd, hwy_net, hwy_skim, mode, tod) 
// Skim drive alone or shared ride links

  /* 
   filter = "truck_only = 1"
   if (mode = "da") then filter = filter + " | hov_only_" + tod + " = 1"
  */


   filter = "available = 0 | transit_only = 1 | walk_bike_only = 1 | pnr_link = 1"
   hov_filter =  "| hov_only_"+tod+" = 1"
   if (mode = "da")   then filter = filter + hov_filter+ " | truck_only = 1" //filter + " | hov_only = 1 | truck_only = 1"
   if (mode = "sr")   then filter = filter + " | truck_only = 1"
   if (mode = "mtrk") then filter = filter + hov_filter+ " | small_veh_only = 1 "//filter + " | hov_only_am = 1 | small_veh_only = 1 "
   if (mode = "htrk") then filter = filter  + hov_filter+ " |  small_veh_only = 1 | no_heavy_truck = 1"






   // update network fields and filter by mode
   netobj = CreateObject("Network.Update", {Network: hwy_net})
   netobj.DisableLinks({Type: "BySet", Filter: filter})
   ok = netobj.Run()

   // run by mode
   obj = CreateObject("Network.Skims")
   obj.LoadNetwork (hwy_net)
   obj.LayerDB = hwy_dbd
   obj.Origins = "int_zone = 1 | ext_zone = 1"
   obj.Destinations = "int_zone = 1 | ext_zone = 1"
   obj.Minimize = "time"
   obj.AddSkimField({"Length", "All"}) 
   //if (mode = "da") then obj.AddSkimField({"Length", "All"}) 
   obj.AddSkimField({"toll_auto", "All"})
   //obj.MaxCost = 120
   obj.OutputMatrix({MatrixFile: hwy_skim, Matrix: "skim", Compression : true, ColumnMajor : false})
   ok = obj.Run()
   //m = obj.GetResults().Data.[Output Matrix]


   // set intrazonals
   cores = {"time"}
   //if (mode = "da") then 
   cores = InsertArrayElements(cores, 1,{"Length (skim)"}) 

   for mat_core in cores do
      mat_opts = null
      mat_opts.MatrixFile = hwy_skim
      mat_opts.Matrix = mat_core
      obj = CreateObject("Distribution.Intrazonal")
      obj.SetMatrix(mat_opts)
      obj.OperationType = "Replace"
      obj.Factor = 0.5
      obj.TreatMissingAsZero = true
      obj.Neighbours = 3
      ok = obj.Run()
   end

   // intrazonal tolls are zero
   m = OpenMatrix(hwy_skim,)
   OpenMatrixFileHandle(m, "w")
   mc = CreateMatrixCurrency(m, "toll_auto (skim)",,,)
   FillMatrix(mc,,,{"Copy",0},{{"Diagonal","Yes"}})
   CloseMatrixFileHandle(m)

   // enable all links after skimming
   netobj = CreateObject("Network.Update", {Network: hwy_net})
   netobj.EnableLinks({Type: "BySet", Filter: filter})
   ok = netobj.Run()
   return(ok)
endmacro

macro "rename_skim_cores" (hwy_skim, mode) 
// Rename default skim cores to standard names

   ok = 1 
   mObj = CreateObject("Matrix", hwy_skim)
  // if (lower(mode) = "da") then 
    //  mObj.RenameCores({CurrentNames: {"Length (skim)"}, NewNames: {"dist"}})
   mObj.RenameCores({CurrentNames: {"time", "toll_auto (skim)","Length (skim)"}, NewNames: {mode + "_time", mode + "_toll",mode + "_dist"}})
   return(ok)
endmacro

macro "combine_mode_skims" (out_dir, tod,scen_dir)
// Combine DA and SR skims into a single file by tod
   //out_dir               

   ok = 1 

   
   da_skim   = scen_dir + "temp\\hwy_da_"  +tod+".mtx" // runmacro("get_highway_mode_skim_file", out_dir, tod, "da")
   sr_skim   = scen_dir + "temp\\hwy_sr_"  +tod+".mtx" //runmacro("get_highway_mode_skim_file", out_dir, tod, "sr")
   mtrk_skim = scen_dir + "temp\\hwy_mtrk_"+tod+".mtx" //runmacro("get_highway_mode_skim_file", out_dir, tod, "mtrk")
   htrk_skim = scen_dir + "temp\\hwy_htrk_"+tod+".mtx" //runmacro("get_highway_mode_skim_file", out_dir, tod, "htrk")
   comb_skim = scen_dir + "temp\\hwy_"+tod+".mtx"

   da_m   = OpenMatrix(da_skim,)
   sr_m   = OpenMatrix(sr_skim,)
   mtrk_m = OpenMatrix(mtrk_skim,)
   htrk_m = OpenMatrix(htrk_skim,)

   da_mc   = CreateMatrixCurrencies(da_m,,,)
   sr_mc   = CreateMatrixCurrencies(sr_m,,,)
   mtrk_mc = CreateMatrixCurrencies(mtrk_m,,,)
   htrk_mc = CreateMatrixCurrencies(htrk_m,,,)

   comb_mat = ConcatMatrices({da_m, sr_m,mtrk_m,htrk_m}, "True",
                              {{"File Name", comb_skim},
                              {"Label", "highway " + tod}})
   return(comb_mat)
endmacro   

macro "calc_rs_fare" (rs_fare_ls, mat)
   // Calculate ridesource fare core
   ok = 1

   //rs_fare_ls = {3.39,3.44,0.51,0.2,1} 

   min_fare = rs_fare_ls[1]
   base_fare = rs_fare_ls[2]
   dist_fare = rs_fare_ls[3]
   time_fare = rs_fare_ls[4]
   fare_wt_adj = rs_fare_ls[5]

   AddMatrixCore(mat,"rs_fare")
   mc = CreateMatrixCurrencies(mat,,,)
   //ShowArray({min_fare,base_fare,dist_fare,})
   mc.rs_fare := max(min_fare, base_fare + mc.sr_dist * dist_fare + mc.sr_time * time_fare)

   // tnc availability sensitivity test
   if (fare_wt_adj <> 1) then do
      mc.rs_fare := mc.rs_fare * fare_wt_adj
   end

  // mc = null
   //mat = null

   return(ok)

endmacro

macro "Skim PK NP Transit Walk"  (scen_dir,out_dir,trn_rts,Transit_net_var)
// Helper function to skim AM and MD transit walk network
   //  trn_rts              = Args.[Transit]
   //  out_dir              = Args.OutputFolder      
   // if Args.DryRun = 1 then Return(1)   
   //  ok = 1

    for tod in {"am", "md","pm","nt"} do
      trn_net = scen_dir + "_networks\\transit_" + tod + ".tnw"  //runmacro("get_transit_network_file", out_dir, tod)
      skim_mtx = scen_dir+"temp\\tw_"+tod+".mtx"  //Args.("TransitWalkSkims - " + tod)
      
      ok = runmacro("set_transit_network", trn_rts, trn_net, tod, "tw",Transit_net_var)
      ok = runmacro("skim_transit_walk",  trn_rts, trn_net, skim_mtx)
    end

    return(ok)

endmacro

macro "Skim PK NP Transit Auto"  (scen_dir,out_dir,trn_rts,vot,drv_time_fact,Transit_net_var)
// Helper function to skim AM and MD transit auto network
   //  trn_rts              = Args.[Transit]
   //  out_dir              = Args.OutputFolder      
   // if Args.DryRun = 1 then Return(1)
   
   // //##  code block //:
   // ok = 1

   for tod in {"am", "md","pm","nt"} do
      trn_net   = scen_dir + "_networks\\transit_" + tod + ".tnw"  //runmacro("get_transit_network_file", out_dir, tod)
      skim_mtx  = scen_dir+"temp\\ta_"+tod+".mtx"                 //Args.("TransitAutoSkims - " + tod)
      parkUsage = scen_dir+"_assignment\\pnr\\pt_park_usage_"+tod+".bin" //  Args.("TransitParkUsage - " + tod)
      
      ok = runmacro("set_transit_network", trn_rts, trn_net, tod, "ta_acc",Transit_net_var)
      ok = runmacro("skim_transit_auto", trn_rts, trn_net, skim_mtx, parkUsage,, vot,drv_time_fact,tod)
    end

    return(ok)

endmacro


// macro "Skim PK NP Logan Express"  (Args)
   // // Helper function to skim Logan Express Service
   //     trn_rts              = Args.[Transit]
   //     out_dir              = Args.OutputFolder      
   //    if Args.DryRun = 1 then Return(1)
      
   //    //##  code block //:
   //    ok = 1

   //    for tod in {"am", "md","pm","nt"} do
   //       trn_net = runmacro("get_transit_network_file", out_dir, tod)
   //       skim_mtx = out_dir + "\\_skim\\lx_" + tod + ".mtx"
   //       parkUsage = out_dir + "\\_skim\\lx_park_usage_" + tod + ".bin"
         
   //       ok = runmacro("set_transit_network", Args, trn_rts, trn_net, tod, "lx")
   //       ok = runmacro("skim_transit_auto", Args, trn_rts, trn_net, skim_mtx, parkUsage, "_lx")

   //       if ({"DEBUG","FULL"} contains Args.loglevel) then do 
   //          omx_file = runmacro("get_transit_omx_skim_file", out_dir, tod, "lx")
   //          runmacro("export_skim_to_omx", skim_mtx, omx_file, "gen_cost")
   //       end
   //     end

   //     return(ok)

// endmacro

macro "skim_transit_walk" ( trn_rts, trn_net, skim_mtx)
// Skim transit walk network

   // core names to be updated
   walk_core_names = {{"Generalized Cost", "gen_cost"},
                  //{"Fare", "fare"},
                  {"Number of Transfers","xfer"},
                  {"In-Vehicle Time","ivtt"},
                  {"Initial Wait Time","iwait"},
                  {"Transfer Wait Time","xwait"},
                  {"Access Walk Time","walk"},
                  //{"Egress Walk Time",}, // will be combined with access walk
                  //{"Transfer Walk Time",}, // will be combined with access walk
                  {"In-Vehicle Distance", "tdist"}}
   skim_vars = {"Generalized Cost", 
                               "Fare",
                               "Number of Transfers",
                               "In-Vehicle Time",
                               "Dwelling Time",
                               "Initial Wait Time",
                               "Transfer Wait Time",
                               "Access Walk Time",
                               "Egress Walk Time",
                               "Transfer Walk Time",
                               "In-Vehicle Distance"}                  

   debug_skim_vars = {"Local Bus.ttime", "Express Bus.ttime", "Bus Rapid.ttime", "Light Rail.ttime",
                               "Heavy Rail.ttime", "Commuter Rail.ttime","Ferry.ttime","Shuttle.ttime","RTA Local Bus.ttime","Regional Bus.ttime"}

   debug_core_names = {{"ttime (Local Bus)", "ivtt_lbus"},
                  {"ttime (Express Bus)", "ivtt_xbus"}, 
                  {"ttime (Bus Rapid)", "ivtt_brt"},
                  {"ttime (Light Rail)","ivtt_lrt"},
                  {"ttime (Heavy Rail)", "ivtt_hrt"},
                  {"ttime (Commuter Rail)","ivtt_cr"},
                  {"ttime (Ferry)","ivtt_fr"},
                  {"ttime (Shuttle)","ivtt_sh"},
                  {"ttime (RTA Local Bus)","ivtt_rta"},
                  {"ttime (Regional Bus)","ivtt_rb"}}

   // // record submode level skims in DEBUG and INFO modes
   // // Including all to have access to mode specific IVT for emat
   // if (({"DEBUG","FULL"} contains Args.loglevel) |
   //       Args.[Transit HRT Time Adjustment] <> 1) then do 
   //    walk_core_names = walk_core_names + debug_core_names
   //    skim_vars = skim_vars + debug_skim_vars
   // end                  

   obj = CreateObject("Network.TransitSkims")
   obj.Method = "PF"
   obj.LayerRS = trn_rts
   obj.LoadNetwork( trn_net )
   obj.OriginFilter = "int_zone = 1 | ext_zone = 1"
   obj.DestinationFilter = "int_zone = 1 | ext_zone = 1"
   obj.SkimVariables = skim_vars

   obj.OutputMatrix({MatrixFile: skim_mtx, Matrix: "Transit_Walk", Compression : true, ColumnMajor : false})
   ok = obj.Run()
   
   mtx = obj.GetResults().Data.[Skim Matrix]

   res = obj.GetResults()
   if !ok then ShowArray(res)


      // update core names
      m = OpenMatrix(skim_mtx, )
      mc = CreateMatrixCurrencies(m,,,)

      // combine walk times
      mc.[Access Walk Time] := mc.[Access Walk Time] + mc.[Egress Walk Time] + mc.[Transfer Walk Time]
      DropMatrixCore(m, "Egress Walk Time")
      DropMatrixCore(m, "Transfer Walk Time")

      // combine dwell with ivtt
      mc.[In-Vehicle Time] := mc.[In-Vehicle Time] + mc.[Dwelling Time]
      DropMatrixCore(m, "Dwelling Time")

      // // sensitivity test - adjust tolls
      // if Args.[Transit Fare Adjustment] <> 1 then do 
      //    mc.Fare := mc.Fare * Args.[Transit Fare Adjustment]
      // end    

      // // sensitivity test - adjust IVT
      // if Args.[Transit HRT Time Adjustment] <> 1 then do 
      //    mc.[In-Vehicle Time] := mc.[In-Vehicle Time] + 
      //                            (nz(mc.[ttime (Heavy Rail)]) * (Args.[Transit HRT Time Adjustment] - 1))
      // end    

      for i in walk_core_names do 
         SetMatrixCoreName(m, i[1], i[2])
      end

   RunMacro("G30 File Close All") // flush out all changes

   // set generalized costs to zero to indicate no transit
   m = OpenMatrix(skim_mtx, )
   gc_mc = CreateMatrixCurrency(m, "gen_cost",,,)
   gc_mc := Nz(gc_mc)
   
   RunMacro("G30 File Close All") // flush out all changes

   return(ok)   

endmacro


macro "skim_transit_auto" (trn_rts, trn_net, skim_mtx, parkUsageTable, lx,vot,drv_time_fact,tod)
// Skim transit auto network

    //vot                  = Args.[Value Of Time] // $ per ivtt min
    //drv_time_fact        = Args.[TransitPath_GlobalWeights].("DriveTimeFactor").Value // ivtt min per drive min
    drv_time_val         = vot * drv_time_fact // $ per drive min       

   auto_core_names = {{"Generalized Cost", "gen_cost"},
                  //{"Fare", "fare"}, 
                  //{"auto_cost", "auto_cost"},                  
                  {"Number of Transfers","xfer"},
                  {"In-Vehicle Time","ivtt"},
                  {"Initial Wait Time","iwait"},
                  {"Transfer Wait Time","xwait"},
                  {"Egress Walk Time","walk"},
                  //{"Transfer Walk Time",}, // will be combined with egress walk
                  {"In-Vehicle Distance", "tdist"},                             
                  {"Access Drive Distance", "ddist"},
                  {"Access Drive Time", "dtime"}}
   skim_vars = {"Generalized Cost", 
                              "Fare",
                              "Number of Transfers",
                              "In-Vehicle Time",
                              "Dwelling Time",
                              "Initial Wait Time",
                              "Transfer Wait Time",
                              "Egress Walk Time",
                              "Transfer Walk Time",
                              "Access Drive Time",                          
                              "In-Vehicle Distance",                               
                              "Access Drive Distance",
                              "auto_cost"}

   debug_skim_vars = {"Local Bus.ttime", "Express Bus.ttime", "Bus Rapid.ttime", "Light Rail.ttime",
                     "Heavy Rail.ttime", "Commuter Rail.ttime","Ferry.ttime","Shuttle.ttime","RTA Local Bus.ttime","Regional Bus.ttime"}

   debug_core_names = {{"ttime (Local Bus)", "ivtt_lbus"},
                  {"ttime (Express Bus)", "ivtt_xbus"}, 
                  {"ttime (Bus Rapid)", "ivtt_brt"},
                  {"ttime (Light Rail)","ivtt_lrt"},
                  {"ttime (Heavy Rail)", "ivtt_hrt"},
                  {"ttime (Commuter Rail)","ivtt_cr"},
                  {"ttime (Ferry)","ivtt_fr"},
                  {"ttime (Shuttle)","ivtt_sh"},
                  {"ttime (RTA Local Bus)","ivtt_rta"},
                  {"ttime (Regional Bus)","ivtt_rb"}}

   // // record submode level skims in DEBUG and INFO modes
   // // Including all to have access to mode specific IVT for emat
   // if (({"DEBUG","FULL"} contains Args.loglevel) |
   //       Args.[Transit HRT Time Adjustment] <> 1) then do
   //    auto_core_names = auto_core_names + debug_core_names
   //    skim_vars = skim_vars + debug_skim_vars
   // end

   obj = CreateObject("Network.TransitSkims")
   obj.Method = "PF"
   obj.LayerRS = trn_rts
   obj.LoadNetwork( trn_net )
   obj.OriginFilter = "int_zone = 1 | ext_zone = 1"
   obj.DestinationFilter = "int_zone = 1 | ext_zone = 1"
   obj.SkimVariables = skim_vars
   obj.AccessParkTable = parkUsageTable
   obj.OutputMatrix({MatrixFile: skim_mtx, Matrix: "Transit_Auto" + lx, Compression : true, ColumnMajor : false})
   ok = obj.Run()
   
   mtx = obj.GetResults().Data.[Skim Matrix]

   res = obj.GetResults()
   if !ok then ShowArray(res)

      // update core names
      m = OpenMatrix(skim_mtx, )
      mc = CreateMatrixCurrencies(m,,,)

      // combine walk times
      mc.[Egress Walk Time] := nz(mc.[Egress Walk Time]) + nz(mc.[Transfer Walk Time])
      DropMatrixCore(m, "Transfer Walk Time")

      // combine dwell with ivtt
      mc.[In-Vehicle Time] := mc.[In-Vehicle Time] + mc.[Dwelling Time]
      DropMatrixCore(m, "Dwelling Time")    

      // correct skim zero bug
      mc.auto_cost := nz(mc.auto_cost)    

      // remove cost from drive time only for am and md 
      //mc.[Access Drive Time] := nz(mc.[Access Drive Time])
       //if ({"am","md"} contains tod) then
          mc.[Access Drive Time] := nz(mc.[Access Drive Time]) - nz(mc.auto_cost)/drv_time_val

      // // sensitivity test - adjust tolls
      // if Args.[Transit Fare Adjustment] <> 1 then do 
      //    mc.Fare := mc.Fare * Args.[Transit Fare Adjustment]
      // end          

      // // sensitivity test - adjust IVT
      // if Args.[Transit HRT Time Adjustment] <> 1 then do 
      //    mc.[In-Vehicle Time] := mc.[In-Vehicle Time] + 
      //                            (nz(mc.[ttime (Heavy Rail)]) * (Args.[Transit HRT Time Adjustment] - 1))
      // end          

      for i in auto_core_names do 
         SetMatrixCoreName(m, i[1], i[2])
    end

    RunMacro("G30 File Close All") // flush out all changes

    // set generalized costs to zero to indicate no transit
    m = OpenMatrix(skim_mtx, )
    gc_mc = CreateMatrixCurrency(m, "gen_cost",,,)
    gc_mc := Nz(gc_mc)
    
    RunMacro("G30 File Close All") // flush out all changes

    return(ok)   

endmacro


macro "Skim NonMotorized Network" (Args)
// Skim walk-bike networks
    ok = 1
    if Args.DryRun = 1 then Return(1)

    out_dir = Args.OutputFolder 
    nm_dbd  = Args.[NonMotorized Links]
    nm_net = runmacro("get_nm_network_file", out_dir)
    nm_skim = Args.[NonMotorizedSkim]

    obj = CreateObject("Network.Skims")
    obj.LoadNetwork (nm_net)
    obj.LayerDB = nm_dbd
    obj.Origins = "Centroids_Only = 1"
    obj.Destinations = "Centroids_Only = 1"
    obj.Minimize = "Length"
   
    obj.OutputMatrix({MatrixFile: nm_skim, Matrix: "skim", Compression : true, ColumnMajor : false})
    ok = obj.Run()
    
    // set intrazonals
    cores = {"Length"}
    for mat_core in cores do
        mat_opts = null
        mat_opts.MatrixFile = nm_skim
        mat_opts.Matrix = mat_core
        obj = CreateObject("Distribution.Intrazonal")
        obj.SetMatrix(mat_opts)
        obj.OperationType = "Replace"
        obj.Factor = 0.5
        obj.TreatMissingAsZero = false
        obj.Neighbours = 3
        ok = obj.Run()
    end

    // update core names
    m = OpenMatrix(nm_skim,)
    OpenMatrixFileHandle(m, "w")
    SetMatrixCoreName(m, "Length",      "dist")
    CloseMatrixFileHandle(m)
    return(ok) 
    
endmacro


macro "set_transit_network" ( trn_rts,trn_net, tod, userclass,Transit_net_var)
// Set transit network by time of day and mode
   //  mode_table = Args.[Transit Mode Table]// "%InputFolder%\\params\\transit_modes_2050_20231231.bin"
   //  transfer_file = Args.[Transit Transfer Table] //"%InputFolder%\\params\\transfer_fare_20231221.bin"
   //  zonal_fares = Args.[Transit Fare Table]//"%InputFolder%\\params\\zonal_fares_20231218.mtx"
   //  path_thr = Args.[Transit Path Thresholds] //{
   //                            // {"MaxTripCost",180},
   //                            // {"MaxModalTotal",180},
   //                            // {"MaxTransfers",6},
   //                            // {"MaxInitialWait",60},
   //                            // {"MaxTransferWait",45},
   //                            // {"MaxAccessWalk",25},
   //                            // {"MaxEgressWalk",25},
   //                            // {"MaxDriveTime",60},
   //                            // {"MaxParkToStopTime",10},
   //                            // {"MinParkingCapacity",25}}
   //  penalties = Args.[Transit Path Penalties] //{
   //                      //          {"TransferPenalty - walk - pk",12},
   //                      //          {"TransferPenalty - walk - np",10},
   //                      //          {"TransferPenalty - auto - pk",18},
   //                      //          {"TransferPenalty - auto - np",20},
   //                      //          {"TransferPenalty - lx",99}}
   //                      // }
   //  global_wgts = Args.[TransitPath_GlobalWeights] //{
   //                      //  {"WalkTimeFactor",3},
   //                      //  {"Fare",1},
   //                      //  {"DriveTimeFactor",10}}
   //  mode_wgts = Args.[TransitPath_ModeWeights] //{
   //                      // {"Time","ivtt_weight"},
   //                      // {"Dwelling","ivtt_weight"},
   //                      // {"InitialWait","iwait_weight"},
   //                      // {"ParkToStopTime","max_pnr_walk"},
   //                      // {"TransferWait","xwait_weight"}}
   //  path_comb = Args.[TransitPath_Combination] //:{
   //                      // {"CombinationFactor",1},
   //                      // {"WalkFactor",0},
   //                      // {"DriveFactor",0.1}}
   //  vot = Args.[Value Of Time] //0.25
   //  pnr = Args.transit_pnr_pfe //:{
   //                      //  {"Alpha",1.5},
   //                      //  {"Beta",2},
   //                      //  {"MaxFactor",25},
   //                      //  {"PnROccupancy",1.2},
   //                      //  {"RMSE_Threshold",10}}


  {mode_table, mode_table_tw ,transfer_file,zonal_fares ,path_thr ,penalties  ,global_wgts,mode_wgts ,path_comb ,vot ,pnr, parkUsageTable} =  Transit_net_var 

    if (userclass = "tw") then mode_table = mode_table_tw //Args.[TW Transit Mode Table]// "%InputFolder%\\params\\transit_modes_2050_20231231_cr1.5.bin"

    ok = 1

    pknp = if (tod = 'am' | tod = 'pm') then 
        'pk' 
    else 
        'np'

    o = CreateObject("Network.SetPublicPathFinder", {RS: trn_rts, NetworkName: trn_net})
    o.UserClasses = {"tw", "ta_acc", "ta_egr", "lx"}
    o.CurrentClass = userclass
    o.CentroidFilter = "int_zone = 1 | ext_zone = 1"
    o.LinkImpedance = "ttime"
    o.DriveTime = "drv_timecost" 
    o.Parameters({
        MaxTripCost: path_thr.("MaxTripCost"),
        MaxTransfers: path_thr.("MaxTransfers"),
        VOT: vot,
        MidBlockOffset: 1, 
        InterArrival: 0.5
        })
    o.AccessControl({
        PermitWalkOnly: false,
        StopAccessField: null,
        MaxWalkAccessPaths: 10,
        WalkAccessNodeField: null
        })
    o.Combination({
        CombinationFactor: path_comb.("CombinationFactor"),
        Walk: path_comb.("WalkFactor"),
        Drive: path_comb.("DriveFactor")
        //ModeField: null,
        //WalkField: null
        })
    o.StopTimeFields({ /*
        InitialPenalty: null,
        TransferPenalty: null,
        DwellOn: null,
        DwellOff: null */
        })
    o.RouteTimeFields({
        Headway: "headway_" + tod
        //InitialWaitOverride: "iwait_" + tod
        //Layover: null,
        //DwellOn: null,
        //DwellOff: null
        })
    o.ModeTable({
        TableName: mode_table,
        ModesUsedField: {"tw_modes", "ta_modes", "ta_modes", "lx_modes"},
        SpeedField: "speed",
        OnlyCombineSameMode: true,
        FreeTransfers: 0
    })
    o.ModeTimeFields({
        DwellOn: "dwell_" + pknp,
        MaxTransferWait: "max_xfer_time"
    })
    o.ModeTransfers({
        TableName: transfer_file,
        FromMode: "from",
        ToMode: "to",
        AtStop: "stop",
        PenaltyTime: "wait",
        Fare: "fare",
        Prohibition: "prohibit",
        FareMethod: "Add"
        })
    o.TimeGlobals({
        //Headway: 14,
        InitialPenalty: 0,
        TransferPenalty: {penalties.("TransferPenalty - walk - " + pknp),
                          penalties.("TransferPenalty - auto - " + pknp),
                          penalties.("TransferPenalty - auto - " + pknp),
                          penalties.("TransferPenalty - lx")},
        MaxInitialWait: path_thr.("MaxInitialWait"),
        MaxTransferWait: path_thr.("MaxTransferWait"),
        //MinInitialWait: 2,
        //MinTransferWait: 2,
        Layover: 15, 
        //DwellOn: 0.25,
        //DwellOff: 0.25,
        MaxAccessWalk: path_thr.("MaxAccessWalk"),
        MaxEgressWalk: path_thr.("MaxEgressWalk"),
        MaxModalTotal: path_thr.("MaxModalTotal")
    })
    o.RouteWeights({/*
        Fare: null,
        Time: null,
        InitialPenalty: null,
        TransferPenalty: null,
        InitialWait: null,
        TransferWait: null,
        Dwelling: null */
    })
    o.ModeWeights({
        Time: mode_wgts.("Time"),
        Dwelling: mode_wgts.("Dwelling"),
        InitialWait: mode_wgts.("InitialWait"),
        TransferWait: mode_wgts.("TransferWait")
    })       
    o.GlobalWeights({/*
        Time: 1,
        InitialPenalty: 1,
        TransferPenalty: 1,
        InitialWait: 2,
        TransferWait: 2,
        Dwelling: 1,*/
        WalkTimeFactor: global_wgts.("WalkTimeFactor"),
        Fare: global_wgts.("Fare"),
        DriveTimeFactor: global_wgts.("DriveTimeFactor")
    })
    o.Fare({
        Type: "Mixed", // Flat, Zonal, Mixed
        FareValue: .99,
        RouteFareField: "fare",
        RouteFareTypeField: "fare_type",
        RouteFareCoreField: "fare_core",
        ModeFareField: "fare",
        ModeFareTypeField: "fare_type",
        ModeFareCoreField: "fare_core_name",
        ZonalFareMethod: "ByRoute",
        StopFareZone: "fare_zone",
        FareMatrix: zonal_fares
        })
        
    o.DriveAccess({
        InUse: {false, true, false, true},
        MaxDriveTime: path_thr.("MaxDriveTime"),
        MaxParkToStopTimeField: mode_wgts.("ParkToStopTime"),
        MaxParkToStopTime: path_thr.("MaxParkToStopTime"),    
        ParkingNodes: "pnr_lot > 0 & parking > " + String(path_thr.("MinParkingCapacity")),
        ParkingNodeCapacity: {
            Alpha: pnr.("Alpha"), 
            Beta: pnr.("Beta"), 
            //Capacity: 100, 
            CapacityField: "parking"}
        //PermitAllWalk: false,
        //AllowWalkAccess: false   
    })

    // reverse origins and destinations for egress parking
    //parkUsageTable = Args.("TransitParkUsage - " + 'am') //"Value":"%OutputFolder%\\_skim\\pt_park_usage_am.bin"

    egressOpts = {
        InUse: {false, false, true, false},
        MaxDriveTime: path_thr.("MaxDriveTime"),
        MaxStopToParkTimeField: mode_wgts.("ParkToStopTime"),
        MaxStopToParkTime: path_thr.("MaxParkToStopTime"),        
        ParkingNodes: "pnr_lot > 0 & parking > " + String(path_thr.("MinParkingCapacity"))
    }
    if GetFileInfo(parkUsageTable) <> null then do
        tempUsageTable = GetTempFileName("*.bin")
        CopyTableFiles(NULL, "FFB", parkUsageTable, NULL, tempUsageTable, NULL)
        dm = CreateObject("DataManager")
        vw = dm.AddDataSource("p", {FileName: tempUsageTable})
        
        oFld = CreateObject("CC.Field", GetFieldFullSpec(vw, "ORIGIN"))
        oFld.Rename("______ORIGIN________")
        oFld = CreateObject("CC.Field", GetFieldFullSpec(vw, "DESTINATION"))
        oFld.Rename("ORIGIN")
        oFld = CreateObject("CC.Field", GetFieldFullSpec(vw, "______ORIGIN________"))
        oFld.Rename("DESTINATION")
        egressOpts.ParkingUsageTable = {,,tempUsageTable,}
    end
   
    o.DriveEgress(egressOpts)

    ok = o.Run()
    res = o.GetResults()
    if !ok then ShowArray(res)
    return(ok) 

endmacro