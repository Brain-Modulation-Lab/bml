function [data] = bml_hstack(cfg, varargin)

% BML_HSTACK concatenates multiple raw data structures by time
%
% Use as
%   data = bml_hstack(cfg, raw1, raw2, raw3, ..., rawN)
% where the configuration can be empty.
%
% cfg.timetol - double: time tolerance in seconds
% cfg.timeref - string: either 'common', 'independent' or 'auto'
%               if 'auto' it is set to common if raws are time contiguous
% cfg.match_labels - logical: indicates if same labels (channel names)
%               should be enforced for concatenation. If false and all
%               raws have the same number of labels, concatenation will
%               proceed with a warning. Defaults to true. 
%
% returns a time-concatenated raw


% 2017.10.27 AB: based on ft_appenddata,
%
% Copyright (C) 2005-2008, Robert Oostenveld
% Copyright (C) 2009-2011, Jan-Mathijs Schoffelen
%
% This file is part of FieldTrip, see http://www.fieldtriptoolbox.org
% for the documentation and details.
%
%    FieldTrip is free software: you can redistribute it and/or modify
%    it under the terms of the GNU General Public License as published by
%    the Free Software Foundation, either version 3 of the License, or
%    (at your option) any later version.
%
%    FieldTrip is distributed in the hope that it will be useful,
%    but WITHOUT ANY WARRANTY; without even the implied warranty of
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%    GNU General Public License for more details.
%
%    You should have received a copy of the GNU General Public License
%    along with FieldTrip. If not, see <http://www.gnu.org/licenses/>.
%
% $Id$

% check if the input data is valid for this function
% for i=1:length(varargin)
%   % FIXME: raw+comp is not always dealt with correctly
%   varargin{i} = ft_checkdata(varargin{i}, 'datatype', {'raw', 'raw+comp'}, 'feedback', 'no');
% end

% set the defaults
cfg.appenddim  = 'time';
timetol       = bml_getopt(cfg, 'timetol', 1e-5);
timeref       = bml_getopt(cfg, 'timeref', 'auto');
match_labels  = bml_getopt(cfg, 'match_labels', true);

isequaltime  = true;
isequallabel = true;
issamelabel  = true;
issamenchan = true;
isequaltrial = true;
isequalfreq  = true;
for i=2:numel(varargin)
  isequaltime  = isequaltime  && isequal(varargin{i}.time , varargin{1}.time );
  isequallabel = isequallabel && isequal(varargin{i}.label, varargin{1}.label);
  issamelabel  = issamelabel  && isempty(setxor(varargin{i}.label, varargin{1}.label));
  issamenchan  = issamenchan && (length(varargin{i}.label) == length(varargin{1}.label));
  isequaltrial = isequaltrial && isequal(numel(varargin{i}.trial),numel(varargin{1}.trial));
  isequalfreq  = isequalfreq && length(uniquetol([varargin{i}.fsample,varargin{1}.fsample],timetol))==1;
end

% ft_selectdata cannot create the union of the data contained in cell-arrays
% make a dummy without the actual data, but keep trialinfo/sampleinfo/grad/elec/opto
% also remove the topo/unmixing/topolabel, if present, otherwise it is not
% possible to concatenate raw and comp data. Note that in append_common the
% topo etc. is removed anyhow, when appenddim = 'chan'
dummy = cell(size(varargin));
for i=1:numel(varargin)
  dummy{i} = removefields(varargin{i}, {'trial', 'time'});
  if strcmp(cfg.appenddim, 'chan')
    dummy{i} = removefields(dummy{i}, {'topo', 'unmixing', 'topolabel'});
  end
  % add a dummy data field, this causes the datatype to become 'chan'
  dummy{i}.dummy       = ones(numel(dummy{i}.label),1);
  dummy{i}.dummydimord = 'chan';
end

if ~isequallabel
  if issamelabel
    for i=2:length(varargin)
      cfg1=[];
      cfg1.label = varargin{1}.label;
      varargin{i} = bml_reorder_channels(cfg1,varargin{i});
    end
  elseif issamenchan && ~match_labels
    ft_warning('concatenating raws with different channel names. Keeping labels of first raw.')
    for i=2:length(varargin)
      varargin{i}.label = varargin{1}.label;
      dummy{i}.label = varargin{1}.label;
    end
  else
  	ft_error('Same channels required to append data by time')
  end
end
if ~isequaltrial
    ft_error('Same number of trials required to append data by time')
end  
if ~isequalfreq
    ft_error('Same Fs required to append data by time')        
end

% don't do any data appending inside the common function
cfg.parameter = {};
% use a low-level function that is shared with the other ft_appendxxx functions
% this will handle the trialinfo/sampleinfo/grad/elec/opto
data = append_common(cfg, dummy{:});
% this is the actual data field that will be appended further down

if ismember('fsample',fieldnames(varargin{1}))
  data.fsample=varargin{1}.fsample;
end
if ismember('hdr',fieldnames(varargin{1}))
  data.hdr=varargin{1}.hdr;
end
%data.sampleinfo=[]; 

if strcmp(timeref,'auto')
  if bml_check_contiguity(cfg,varargin{:})
    timeref = 'common';
  else
    timeref = 'independent';
  end
end

if strcmp(timeref,'independent')
  dat = cell(1,0);
  tim = cell(1,0);
  for t=1:numel(varargin{1}.trial)
    trial_dat=[];
    trial_tim=[];
    curtime=varargin{i}.time{t}(1);
    for i=1:numel(varargin)
      trial_dat = cat(2, trial_dat, varargin{i}.trial{t});
      time0=varargin{i}.time{t}(1);
      trial_tim = cat(2, trial_tim, curtime-time0+1/data.fsample+varargin{i}.time{t});
      curtime=trial_tim(end);
    end
    dat = cat(2, dat, trial_dat);
    tim = cat(2, tim, trial_tim);
  end
  data.trial = dat;
  data.time  = tim;      
elseif strcmp(timeref,'common')
  dat = cell(1,0);
  tim = cell(1,0);
  for t=1:numel(varargin{1}.trial)
    trial_dat=[];
    trial_tim=[];
    for i=1:numel(varargin)
      trial_dat = cat(2, trial_dat, varargin{i}.trial{t});
      trial_tim = cat(2, trial_tim, varargin{i}.time{t});
    end
    dat = cat(2, dat, trial_dat);
    tim = cat(2, tim, trial_tim);
  end
  data.trial = dat;
  data.time  = tim; 
else
  error('unknown cfg.timeref');
end

