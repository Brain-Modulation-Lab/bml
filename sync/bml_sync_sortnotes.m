function sortnotes = bml_sync_sortnotes(cfg)
% BML_SYNC_SORTNOTES 

roi           = bml_getopt(cfg,'roi');
roi           = bml_roi_table(roi);
sortnotes     = bml_getopt(cfg,'sortnotes');
WaveformFreq	= bml_getopt(cfg,'WaveformFreq');
plexon        = bml_getopt_single(cfg,'plexon');
timetol         = bml_getopt(cfg,'timetol',1e-3);

partialchunks = bml_getopt(cfg,'partialchunks',false);

assert(~isempty(roi),"roi table required");
assert(isfile(plexon),"Valid plexon file required");
% assert(isfile(sortnotes),"Valid sortnotes file required");

plexon_src    = strrep(plexon,'.plx','.mat');
if ~isfile(plexon_src)
    plexon_src = [];
end

plexon_src	  = bml_getopt_single(cfg,'plexon_src',plexon_src);

FileMapping = [];
label = [];
if ~isempty(plexon_src) && isfile(plexon_src)
    src = matfile(plexon_src);
    if ismember('FileMapping',fieldnames(src))
        FileMapping = src.FileMapping;
    end
    if ismember('Channels',fieldnames(src))
        label = src.Channels;
    end
end
FileMapping   = bml_getopt(cfg,'FileMapping',FileMapping);
label         = bml_getopt(cfg,'label',label);

electrode     = bml_getopt(cfg,'electrode');
if ~isempty(label) && ~isempty(electrode) && ...
        all(ismember({'electrode','channel'},electrode.Properties.VariableNames))
    label=bml_map(label,electrode.channel,electrode.electrode);
end

FM_VARS={'name','nSamples','Fs','raw1','raw2'};
SY_VARS={'starts','ends','t1','s1','t2','s2','name', 'nSamples'};

assert(~isempty(FileMapping),"FileMapping required");
assert(all(ismember(FM_VARS,FileMapping.Properties.VariableNames)),"Invalid FileMapping table");
assert(all(ismember(SY_VARS,roi.Properties.VariableNames)),"Invalid roi table");

fm = FileMapping(:,FM_VARS);
sy = roi(ismember(roi.name,fm.name),SY_VARS);
syfm=join(sy,fm,'Keys','name');

assert(all(syfm.nSamples_sy==syfm.nSamples_fm), "Inconsistent number of samples");

if partialchunks
    
    syfm.nSamples = syfm.nSamples_sy;
    
    % first fm file -- assume raw2 corresponds to end of chunk
    syfm.s1(syfm.raw1 == 1) = syfm.raw2(syfm.raw1 == 1) - syfm.nSamples(syfm.raw1 == 1) + syfm.s1(syfm.raw1 == 1);
    syfm.s2(syfm.raw1 == 1) = syfm.raw2(syfm.raw1 == 1) - syfm.nSamples(syfm.raw1 == 1) + syfm.s2(syfm.raw1 == 1);    
    
    % remaining fm files -- assume raw1 corresponds to start of chunk
    syfm.s1(syfm.raw1 > 1) = syfm.raw1(syfm.raw1 > 1) + syfm.s1(syfm.raw1 > 1) - 1;
    syfm.s2(syfm.raw1 > 1) = syfm.raw1(syfm.raw1 > 1) + syfm.s2(syfm.raw1 > 1) - 1;

    %     syfm = syfm((syfm.raw2-syfm.raw1+1) == syfm.nSamples,:);
    %     assert(~isempty(syfm), "No vaid sync chunks found for consolidation.");
    
else
    
    syfm = syfm((syfm.raw2-syfm.raw1) == (syfm.s2-syfm.s1),:);
    assert(~isempty(syfm), "No vaid sync chunks found for consolidation.");
    
    syfm.s1=syfm.raw1;
    syfm.s2=syfm.raw2;
    syfm.nSamples = syfm.nSamples_sy;
    
end

cfg1=[];
cfg1.timetol = timetol; 
cfg1.roi=syfm;
cfg1.rowisfile=false;
spike_sync=bml_sync_consolidate(cfg1);

sortnotes.starts = bml_idx2time(spike_sync,sortnotes.starts*WaveformFreq);
sortnotes.ends = bml_idx2time(spike_sync,sortnotes.ends*WaveformFreq);
sortnotes = bml_annot_table(sortnotes,'sortnotes');
end

