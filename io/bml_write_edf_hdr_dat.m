function bml_write_edf_hdr_dat(filename, edf_hdr, edf_dat)

% BML_WRITE_EDF_HDR_DAT(filename, header, data)
%
% Writes a EDF file from the given header (only label, Fs, nChans are of interest)
% and the data (unmodified). Digital and physical limits are derived from the data
% via min and max operators. The EDF file will contain N records of 1 sample each,
% where N is the number of columns in 'data'.
%
% For sampling rates > 1 Hz, this means that the duration of one data "record"
% is less than 1s, which some EDF reading programs might complain about. At the
% same time, there is an upper limit of how big (in bytes) a record should be,
% which we could easily violate if we write the whole data as *one* record.

% Copyright (C) 2010, Stefan Klanke
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

[nChans,nSamples] = size(edf_dat);

assert(edf_hdr.NS == nChans, 'Data dimension does not match header information');
assert( nChans <= 9999, 'Cannot write more than 9999 channels to an EDF file.');
assert( nSamples <= 99999999, 'Cannot write more than 99999999 data records (=samples) to an EDF file.');
assert(isreal(edf_dat),'Cannot write complex-valued data');

labels = edf_hdr.Label;
data = int16(edf_dat);
digMin = sprintf('%-8i', edf_hdr.DigMin);
digMax = sprintf('%-8i', edf_hdr.DigMax);
physMin = format_to_fit(edf_hdr.PhysMin);
physMax = format_to_fit(edf_hdr.PhysMax);

% write in data blocks of approximately one second, with an integer number of samples
Fs = edf_hdr.SampleRate(1);
blocksize = round(Fs);
nBlocks = floor(nSamples/blocksize);

fid = fopen_or_error(filename, 'wb', 'ieee-le');
% first write fixed part
%fprintf(fid, '0       ');   % version
fprintf(fid, '%-8s', edf_hdr.VERSION);
fprintf(fid, '%-80s', edf_hdr.PID);
fprintf(fid, '%-80s', edf_hdr.RID);

%c = clock;
c = edf_hdr.T0;
fprintf(fid, '%02i.%02i.%02i', c(3), c(2), mod(c(1),100)); % date as dd.mm.yy
fprintf(fid, '%02i.%02i.%02i', c(4), c(5), round(c(6))); % time as hh.mm.ss

fprintf(fid, '%-8i', 256*(1+nChans));  % number of bytes in header
fprintf(fid, '%44s', ' '); % reserved (44 spaces)
fprintf(fid, '%-8i', nBlocks); % number of data records
fprintf(fid, '%8f', blocksize/Fs); % duration of data record in seconds
fprintf(fid, '%-4i', nChans);  % number of signals = channels

fwrite(fid, labels', 'char*1'); % labels
fwrite(fid, 32*ones(80,nChans), 'uint8'); % transducer type (all spaces)
fwrite(fid, 32*ones(8,nChans), 'uint8'); % phys dimension (all spaces)
fwrite(fid, physMin', 'char*1'); % physical minimum
fwrite(fid, physMax', 'char*1'); % physical maximum
fwrite(fid, digMin', 'char*1'); % digital minimum
fwrite(fid, digMax', 'char*1'); % digital maximum
fwrite(fid, 32*ones(80,nChans), 'uint8'); % prefiltering (all spaces)
for k=1:nChans
  fprintf(fid, '%-8i', blocksize); % samples per record (each channel)
end
fwrite(fid, 32*ones(32,nChans), 'uint8'); % reserved (32 spaces / channel)

% now write data
begsample = 1;
endsample = blocksize;
while endsample<=nSamples
  fwrite(fid, data(:,begsample:endsample)', 'int16');
  begsample = begsample+blocksize;
  endsample = endsample+blocksize;
end
fclose(fid);

end

function formattedValue = format_to_fit(value)
    % Initialize a cell array to store formatted strings with varying precision
    formattedStrings = cell(1, 7);
    formattedStrings{1} = sprintf('%-8.7g', value);
    formattedStrings{2} = sprintf('%-8.6g', value);
    formattedStrings{3} = sprintf('%-8.5g', value);
    formattedStrings{4} = sprintf('%-8.4g', value);
    formattedStrings{5} = sprintf('%-8.3g', value);
    formattedStrings{6} = sprintf('%-8.2g', value);
    formattedStrings{7} = sprintf('%-8.1g', value);
    
    % Find the first formatted string that fits within the specified width
    formattedValue = formattedStrings{find(cellfun(@length, formattedStrings) <= 8 * length(value), 1, 'first')};
    
    % In case none of the strings fit, default to the least detailed
    if isempty(formattedValue)
        formattedValue = formattedStrings{end};  % Use the lowest precision
    end
end



