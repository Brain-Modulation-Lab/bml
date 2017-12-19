function sync = bml_sync_fortify(cfg)

% BML_SYNC_FORTIFY ensures consistency between synchronization chunks

if istable(cfg)
  cfg = struct('roi',cfg);
end
sync = bml_roi_table(bml_getopt(cfg,'roi'));

rm_moving_files = bml_getopt(cfg,'rm_moving_files',true);

if istrue(rm_moving_files)
  MF = ~cellfun(@isempty,regexp(sync.name,'[RL]T[1-5]D[-]{0,1}\d+\.\d+[+-]MF\d+\.mat','once'));
  sync = sync(~MF,:); 
end

keyboard


