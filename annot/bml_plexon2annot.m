function [annot, spike] = bml_plexon2annot(cfg)

% BML_PLEXON2ANNOT loads spike events from plexon file
%
% Use as
%   annot = bml_plexon2annot(cfg)
%
% cfg.roi            - roi table with neuroomega sync information
% cfg.plexon         - (path/)filename to plexon file
% cfg.plexon_src     - path to preprocessed mat file for plexon
%                      inferred from cfg.plaxon_src if not given
%                      and cfg.FileMapping not provided
% cfg.file_mapping   - table with file mapping to vector analyzed by
%                      plexon. Loaded from cfg.plexon_src->FileMapping if not given
% cfg.label          - vector of channel names. Extracted from 'channels'
%                      cell array in cfg.plexon_src->Channels if not provided
% cfg.electrode      - table with variables channel and electrode. used to 
%                      rename the labels. 
%
% Returns
% annot - annotation table with time of spikes in global time coordinates
% spike - ft_datatype_spike structure as returned by ft_read_spike (with
%         renamed labels)


%loading parameters and defaults
roi           = bml_getopt(cfg,'roi');
roi           = bml_roi_table(roi);
assert(~isempty(roi),"roi table required");

timetol       = bml_getopt(cfg,'timetol',1e-3);

plexon        = bml_getopt_single(cfg,'plexon');
assert(isfile(plexon),"Valid plexon file required");

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
  if ismember('Channels',fieldnames(src))label
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

partialchunks = bml_getopt(cfg,'partialchunks',false);

%loading fieldtrip spike structure from plexon file
spike= ft_read_spike(plexon);

if isempty(label)
  label = spike.label;
end
if size(label,2) < size(label,1)
  label = label';
end
spike.label = label;

FM_VARS={'name','nSamples','Fs','raw1','raw2'};
SY_VARS={'starts','ends','t1','s1','t2','s2','name', 'nSamples'};

assert(~isempty(FileMapping),"FileMapping required");
assert(length(label)==length(spike.label),"Incorrect label");
assert(all(ismember(FM_VARS,FileMapping.Properties.VariableNames)),"Invalid FileMapping table");
assert(all(ismember(SY_VARS,roi.Properties.VariableNames)),"Invalid roi table");

%% WJL deal with Plexon files with degenerate channels
if length(spike.timestamp)>length(label)
    fprintf('BML_PLEXON2ANNOT: Consolidating degenerate channels.\n')
    PlexonChannelNames = unique({spike.hdr.ChannelHeader.Name});
    if length(PlexonChannelNames) ~= length(label)
        fprintf('BML_PLEXON2ANNOT: Channel number does not match.\n')
    else
        chmap = {};
        for ch = 1:length(label)
        chmap{ch} = find( cellfun(@(x) find(strcmp(x, PlexonChannelNames)), {spike.hdr.ChannelHeader.Name})==ch & ...
            ~cellfun(@isempty, spike.timestamp) );
        end
        
        if any(cellfun(@(x) length(x)~=1, chmap))
            fprintf('BML_PLEXON2ANNOT: Cannot match up channels.\n')
        else
        chmap = cell2mat(chmap);
        % remap channels
        spike.timestamp = spike.timestamp(chmap);
        spike.unit = spike.unit(chmap);
        spike.waveform = spike.waveform(chmap);
        end
    end
end

annot=table();
for i=1:length(spike.timestamp)
  if ~isempty(spike.timestamp{i})
    
    %creating sync table for the spike data
    assert(max(spike.timestamp{i}) <= max(FileMapping.raw2), "Invalid timestamp");
    
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
    cfg1.roi=syfm;
    cfg1.rowisfile=false;
    cfg1.timetol = timetol;
    spike_sync=bml_sync_consolidate(cfg1);
    
    %creating table with spikes
    st = table(bml_idx2time(spike_sync,spike.timestamp{i})',spike.unit{i}');
    st.Properties.VariableNames = {'starts','unit'};
    st.channel(:)=label(i);
    st.spike_idx=(1:height(st))';
    
    annot=[annot;st];
  end  
end

annot.ends = annot.starts;
annot = bml_annot_table(annot);
