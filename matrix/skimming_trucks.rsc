
//this code is based on the "skimming" code in the tdm23, 
// with more tod (pm, nt) and more skims ( like truck skims) this was needed for preparing the data request by Tredis. 
macro "run"

    scen_dir ="D:\\Projects\\allston\\tdm23\\outputs\\AssignTransitOnly\\bld2050_2\\" //update me 
    hwy_dbd = scen_dir + "_networks\\LinksNodes.dbd"
    out_dir = scen_dir + "temp\\"

    // ***** place holders *****
    log_level = 1
    rs_fare_ls = null
    // ***** end           *****
 
    runmacro ("Skim Highway",scen_dir,hwy_dbd,out_dir,log_level,rs_fare_ls)

endmacro


macro "Skim Highway"  (scen_dir,hwy_dbd,out_dir,log_level,rs_fare_ls)
// Helper function to skim AM and MD highway network
   
   /*
    hwy_dbd              = Args.[Highway]  
    out_dir              = Args.OutputFolder    
    log_level            = Args.loglevel  
   

   if Args.DryRun = 1 then Return(1)
   */
    ok = 1

   

    for tod in {"am","md","pm","nt"} do //{"am","md","pm","nt"}
      for mode in {"da","sr","mtrk","htrk"} do
        // hwy_net = Args.("Highway Net - " + tod)
        hwy_net = scen_dir + "_networks\\hwy_"+tod+".net"
        hwy_skim = scen_dir + "temp\\hwy_"+mode+"_"+tod+".mtx"
         //hwy_skim = runmacro("get_highway_mode_skim_file", out_dir, tod, mode)
         ok = runmacro("skim_highway_mode", hwy_dbd, hwy_net, hwy_skim, mode, tod)
         ok = runmacro("rename_skim_cores", hwy_skim, mode)
      end

      // combine skims
      comb_mat = runmacro("combine_mode_skims", out_dir, tod,scen_dir)

      // ***** dropped: add rs fare core using rs_fare_ls *****

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
// Combine skims into a single file by tod
   //out_dir               
   
   // ***** dropped: codes about other matrices *****
   mtrk_skim = scen_dir + "temp\\hwy_mtrk_"+tod+".mtx" //runmacro("get_highway_mode_skim_file", out_dir, tod, "mtrk")
   htrk_skim = scen_dir + "temp\\hwy_htrk_"+tod+".mtx" //runmacro("get_highway_mode_skim_file", out_dir, tod, "htrk")
   comb_skim = scen_dir + "temp\\truck_skims_"+tod+".mtx"

   mtrk_m = OpenMatrix(mtrk_skim,)
   htrk_m = OpenMatrix(htrk_skim,)

   mtrk_mc = CreateMatrixCurrencies(mtrk_m,,,)
   htrk_mc = CreateMatrixCurrencies(htrk_m,,,)

   comb_mat = ConcatMatrices({mtrk_m,htrk_m}, "True",
                              {{"File Name", comb_skim},
                              {"Label", "truck " + tod}})
                              
   return(comb_mat)
endmacro

      // ***** dropped: other macros *****