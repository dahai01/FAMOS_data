
macro "skim_heavy_truck"

    hwy_dbd = "C:\\Projects\\tdm23\\outputs\\Base\\_networks\\LinksNodes.dbd"
    hwy_net = "C:\\Projects\\tdm23\\outputs\\Base\\_networks\\hwy_am.net"
    hwy_skim = "C:\\temp\\truck_skim.mtx"
    mode = "htrk"

    runmacro("skim_highway_mode", hwy_dbd, hwy_net, hwy_skim, mode) 

endmacro


macro "skim_highway_mode" (hwy_dbd, hwy_net, hwy_skim, mode) 
   //### Purpose: Skim drive alone or shared ride links 
   //##  Inputs:  highway network with congested times
   //## Outputs:  highway skim by mode
   
   filter = "available = 0 | transit_only = 1 | walk_bike_only = 1 | pnr_link = 1"
   if (mode = "da") then filter = filter + " | hov_only = 1 | truck_only = 1"
   if (mode = "htrk") then filter = filter + " | hov_only_am = 1 | small_veh_only = 1 | no_heavy_truck = 1"

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
   if (mode = "da") then obj.AddSkimField({"Length", "All"}) 
   obj.AddSkimField({"toll_auto", "All"})
   //obj.MaxCost = 120
   obj.OutputMatrix({MatrixFile: hwy_skim, Matrix: "skim", Compression : true, ColumnMajor : false})
   ok = obj.Run()
   //m = obj.GetResults().Data.[Output Matrix]


   // enable all links after skimming
   netobj = CreateObject("Network.Update", {Network: hwy_net})
   netobj.EnableLinks({Type: "BySet", Filter: filter})
   ok = netobj.Run()
   return(ok)
endmacro