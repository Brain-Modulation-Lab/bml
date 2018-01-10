function sync = bml_sync_transfer_trellis_filetype(cfg)

% BML_SYNC_TRANSFER_TRELLIS_FILETYPE transfer sync info between trellis filetypes
%
% Use as 
%   sync = bml_sync_transfer_trellis_filetype(cfg)
%
% This function calculates synchronization rows for trellis filetypes,
% based on another filetype. Normally trellis files are sync using the ns5 file.
% This function creates registries for files at different sampling rate,
% such as ns2 files. 
%
% cfg.roi           - original sync table (normaly with filetype='trellis.ns5')
% cfg.filetype      - char, new filetype. Defaults to 'trellis.ns2'
% cfg.extension     - char, extension of new filetype to transfer sync.
%                     Default is determined from filetype (e.g. 'ns2')
% cfg.sync_filetype - char, original sync filetype (defaults to 'ns5')
% cfg.sync_chantype - char, original sync chantype (defaults to empty)
% cfg.timetol       - float, time tolerance. Defaults to 1e-4
%
% returns an roi table with the new entries for the trellis filetype.
%

filetype          = bml_getopt_single(cfg,'filetype','trellis.ns2');
[~,~,extension]   = fileparts(filetype);
extension         = bml_getopt_single(cfg,'extension',extension);
sync_filetype     = bml_getopt_single(cfg,'sync_filetype','trellis.ns5');
sync_chantype     = bml_getopt_single(cfg,'sync_chantype');
roi               = bml_getopt(cfg,'roi');
timetol           = bml_getopt(cfg,'timetol',1e-4);

assert(~isempty(roi),'roi required');

% hdr1 = ft_read_header(fullfile(roi.folder{1},roi.name{1}),'chantype','chaninfo');

REQUIRED_VARS = {'s1','t1','s2','t2','folder','name','nSamples','Fs','chantype','filetype'};
assert(all(ismember(REQUIRED_VARS,roi.Properties.VariableNames)),...
  'Variables %s required',strjoin(REQUIRED_VARS))

sync_filetype_roi = roi(strcmp(roi.filetype,sync_filetype),:);

sync=table();
for i=1:height(sync_filetype_roi)
  row=sync_filetype_roi(i,:);
  
  %reading header
  [~,n,~]=fileparts(row.name{1});
  fn=fullfile(row.folder{1},[n,extension]);
  if ~exist(fn,'file')
    warning("%s doesn't exist",fn);
  else
    hdr = ft_read_header(fn,'chantype',sync_chantype);
    
    %checking consistent length between files
    if abs(row.nSamples ./ row.Fs - hdr.nSamples ./ hdr.Fs) > timetol
      warning("%s has a different time duration than %s",fn,row.name{1});
    end
    
    Fs = (row.s2-row.s1)/(row.t2-row.t1); %real sampling rate from coordinates
    nFr = hdr.Fs/row.Fs; %nominal sampling rate ratio nFs/nFs'
    new_Fs = nFr .* Fs; %new real sampling rate  
    
    %assuming same file beggining and end times
    t0 = row.t1 - (row.s1-0.5)/Fs; %time of begging of file 
    tf = row.t2 + (row.nSamples-(row.s2-0.5))/Fs; %time of end of file 
    
    %creating new row
    new=row;
    new.Fs = hdr.Fs;
    new.nSamples = hdr.nSamples;
    new.filetype = {filetype};
    new.name = {[n,extension]};
    
    %new coordinates
    new.s1 = ceil(nFr .* (row.s1 - 0.5));
    new.s2 = ceil(nFr .* (row.s2 - 0.5));
    new.t1 = t0 + (new.s1 - 0.5)/new_Fs;
    new.t2 = tf - (new.nSamples - (new.s2 - 0.5))/new_Fs;

    %completing other variables
    if ismember('nChans',new.Properties.VariableNames)
    	new.nChans(:) = hdr.nChans;
    end
    if ismember('nTrials',new.Properties.VariableNames)
    	new.nTrials(:) = hdr.nTrials;
    end    
    if ismember('chanunit',new.Properties.VariableNames)
    	new.chanunit = {strjoin(unique(hdr.chanunit))};
    end 
    
    sync = [sync; new];
  end
end

%completing common variables
if ismember('sync_type',sync.Properties.VariableNames)
  sync.sync_type(:)={'slave'};
end
if ismember('bytes',sync.Properties.VariableNames)
  sync.bytes(:)=nan;
end

sync = bml_annot_table(sync,'sync');


