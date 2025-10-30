macro "export_truck_od" (scen_dir, omx_dir)

   ok = 2

   selected_cores = {"mtrk", "htrk"}
   current_core = "mtrk" // can be null
   for tod in {"am", "md", "pm", "nt"} do
      mtx_file = scen_dir + "\\_demand\\tod\\od_trk_" + tod + ".mtx"
      omx_file = omx_dir + "\\od_trk_" + tod + ".omx"
      ok = runmacro ("export_skim_to_omx", mtx_file, omx_file, current_core, selected_cores)
   end
   return(ok)
endmacro



// exports from mtx to omx
macro "export_skim_to_omx" (mtx_file, omx_file, root_mc, selected_cores)
//

   ok = 1
   
   // add simple index of number sequence (needed for OMX outputs)
   m = OpenMatrix(mtx_file,)
   all_cores = GetMatrixCoreNames(m)
   curr_idx = GetMatrixIndex(m)
   index_ids = GetMatrixIndexIDs(m,curr_idx[1])
   mat_size = ArrayLength(index_ids)
   seq_idx = Vector(mat_size,"Short",{{"Sequence",1,1}})

   idx_t = GetTempFileName(".bin")
   idx_vw = CreateTable("idx_vw", idx_t,"FFB",
               {{"old_idx", "Integer", 10, 0, "True"},
               {"new_idx", "Integer", 10, 0,}})

   rh = AddRecords(idx_vw, null, null, {{"Empty Records", mat_size}})
   SetDataVector(idx_vw + "|","old_idx" ,ArrayToVector(index_ids),)
   SetDataVector(idx_vw + "|","new_idx" ,seq_idx,)

   mobj = CreateObject("Caliper.Matrix")
   mobj.AddIndex({MatrixFile: mtx_file, 
                ViewName: idx_vw,
                Dimension: "Both", 
                OriginalID: "old_idx",
                NewID: "new_idx",
                IndexName: "ID"})

   mc = CreateMatrixCurrency(m,root_mc,,,)
   // mc = CreateMatrixCurrency(m,,,,) // can do the works with no core specified
    
   if (selected_cores = null) then
      CopyMatrix(mc,{{"File Name", omx_file}, 
                    {"OMX", True}, //all cores if not specified
                    {"File Based", "Yes"}})
   else do
      pos_arr = null // not `pos_arr = {}`
      for c in selected_cores do
         p = ArrayPosition(all_cores, {c}, )
         pos_arr = pos_arr + {p}
      end
   CopyMatrix(mc,{{"File Name", omx_file}, 
                    {"OMX", True},
                    {"Cores", pos_arr},
                    {"File Based", "Yes"}})
   end
   return (ok)
endmacro
