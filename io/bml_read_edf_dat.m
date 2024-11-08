function [edf_dat] = bml_read_edf_dat(edf_hdr, begsample, endsample, chanindx)

% BML_READ_EDF_DAT reads specified samples from an edf_hdr datafile. 
% Or use as
%   [dat] = read_edf(filename, edf_hdr, begsample, endsample, chanindx)
% where
%    filename        name of the datafile, including the .edf extension
%    hdr             header structure, see above
%    begsample       index of the first sample to read
%    endsample       index of the last sample to read
%    chanindx        index of channels to read (optional, default is all)
% This returns a Nchans X Nsamples data matrix

% Copyright (C) 2006, Robert Oostenveld and others
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

assert(nargin >= 1, "header required");
filename = edf_hdr.FileName;
useChanindx = true;
if nargin < 4
  chanindx = 1:edf_hdr.NS;
  useChanindx = false;
end
if nargin < 3
  endsample = edf_hdr.NRec * edf_hdr.SPR(1);
end
if nargin < 2
  begsample = 1;
end



  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  % read the data
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  
  % There can be an optional chansel field containing a list of predefined channels.
  % These channels are in that case also the only ones represented in the FieldTrip
  % header, which means that the other channels are simply not visible to the naive
  % user. This field can be present because the user specified an explicit channel
  % selection in FT_READ_HEADER or because the read_edf function had to automatically
  % choose a subset to cope with heterogenous sampling rates or even both.  In any
  % case, at this point in the file reading process the contents of the chansel field
  % has the proper specification for channel selection, taking into account both the
  % user channel selection as well as any correction that might have been made due to
  % heterogenous sampling rates.
  
  if useChanindx
    epochlength = edf_hdr.SPR(chanindx(1));   % in samples for the selected channel
    blocksize   = sum(edf_hdr.SPR);           % in samples for all channels
    chanoffset  = edf_hdr.SPR;
    chanoffset  = round(cumsum([0; chanoffset(1:end-1)]));
    nchans      = length(chanindx);       % get the selection from the subset of channels
  else
    epochlength = edf_hdr.SPR(1);             % in samples for a single channel
    blocksize   = sum(edf_hdr.SPR);           % in samples for all channels
    nchans      = edf_hdr.NS;                 % use all channels
  end
  
  % determine the trial containing the begin and end sample
  begepoch    = floor((begsample-1)/epochlength) + 1;
  endepoch    = floor((endsample-1)/epochlength) + 1;
  nepochs     = endepoch - begepoch + 1;
  
  % allocate memory to hold the data
  dat = zeros(length(chanindx),nepochs*epochlength);
  
  % read and concatenate all required data epochs
  for i=begepoch:endepoch
    if useChanindx
      % only a subset of channels with consistent sampling frequency is read
      offset = edf_hdr.HeadLen + (i-1)*blocksize*2; % in bytes
      % read the complete data block
      buf = readLowLevel(filename, offset, blocksize); % see below in subfunction
      for j=1:length(chanindx)
        % cut out the part that corresponds with a single channel
        dat(j,((i-begepoch)*epochlength+1):((i-begepoch+1)*epochlength)) = buf((1:epochlength) + chanoffset(chanindx(j)));
      end
      
    elseif length(chanindx)==1
      % this is more efficient if only one channel has to be read, e.g. the status channel
      offset = edf_hdr.HeadLen + (i-1)*blocksize*2; % in bytes
      offset = offset + (chanindx-1)*epochlength*2;
      % read the data for a single channel
      buf = readLowLevel(filename, offset, epochlength); % see below in subfunction
      dat(:,((i-begepoch)*epochlength+1):((i-begepoch+1)*epochlength)) = buf;
      
    else
      % read the data from all channels, subsequently select the desired channels
      offset = edf_hdr.HeadLen + (i-1)*blocksize*2; % in bytes
      % read the complete data block
      buf = readLowLevel(filename, offset, blocksize); % see below in subfunction
      buf = reshape(buf, epochlength, nchans);
      dat(:,((i-begepoch)*epochlength+1):((i-begepoch+1)*epochlength)) = buf(:,chanindx)';
    end
  end
  
  % select the desired samples
  begsample = begsample - (begepoch-1)*epochlength;  % correct for the number of bytes that were skipped
  endsample = endsample - (begepoch-1)*epochlength;  % correct for the number of bytes that were skipped
  edf_dat = dat(:, begsample:endsample);

end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SUBFUNCTION for reading the 16 bit values
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function buf = readLowLevel(filename, offset, numwords)
  is_below_2GB = offset < 2*1024^2;
  read_16bit_success = true;
  if is_below_2GB
    % use the external mex file, only works for <2GB
    try
      buf = read_16bit(filename, offset, numwords);
    catch e
      read_16bit_success = false;
    end
  end
  if ~is_below_2GB || ~read_16bit_success
    % use plain matlab, thanks to Philip van der Broek
    fp = fopen(filename,'r','ieee-le');
    status = fseek(fp, offset, 'bof');
    if status
      ft_error(['failed seeking ' filename]);
    end
    [buf,num] = fread(fp,numwords,'bit16=>double');
    fclose(fp);
    if (num<numwords)
      ft_error(['failed reading ' filename]);
      return
    end
  end
end
