
// exports from mtx to omx
macro "export_skim_to_omx" (mtx_file, omx_file, root_mc)
//
   ok = 1

   // add simple index of number sequence (needed for OMX outputs)
   m = OpenMatrix(mtx_file,)
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

   // mc = CreateMatrixCurrency(m,root_mc,,,)
   mc = CreateMatrixCurrency(m,,,,)
   CopyMatrix(mc,{{"File Name", omx_file}, 
                    {"OMX", True},
                    {"File Based", "Yes"}})
   return(ok)
endmacro
