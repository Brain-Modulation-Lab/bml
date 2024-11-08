function edf_hdr = bml_read_edf_hdr(filename)

% BML_READ_edf_hdr_HEADER reads a header from a edf_hdr datafile. 
%
% Use as
%   [hdr] = bml_read_edf_hdr(filename)
% where
%    filename        name of the datafile, including the .edf extension


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

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  % read the header, this code is from EEGLAB's openbdf
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  FILENAME = filename;
  
  % defines Seperator for Subdirectories
  SLASH='/';
  BSLASH=char(92);
  
  cname=computer;
  if cname(1:2)=='PC' 
    SLASH=BSLASH; 
  end
  
  fid=fopen_or_error(FILENAME,'r','ieee-le');
  
  edf_hdr.FILE.FID=fid;
  edf_hdr.FILE.OPEN = 1;
  edf_hdr.FileName = FILENAME;

  [edf_hdr.FILE.Path,edf_hdr.FILE.Name,edf_hdr.FILE.Ext] = fileparts(FILENAME);
  
%   PPos=min([find(FILENAME=='.',1,'last') length(FILENAME)+1]);
%   SPos=max([0 find((FILENAME=='/') | (FILENAME==BSLASH))]);
%   edf_hdr.FILE.Ext = FILENAME(PPos+1:length(FILENAME));
%   edf_hdr.FILE.Name = FILENAME(SPos+1:PPos-1);
%   if SPos==0
%     edf_hdr.FILE.Path = pwd;
%   else
%     edf_hdr.FILE.Path = FILENAME(1:SPos-1);
%   end
  edf_hdr.FileName = [edf_hdr.FILE.Path SLASH edf_hdr.FILE.Name edf_hdr.FILE.Ext];
  
  H1=char(fread(edf_hdr.FILE.FID,256,'uint8=>char')');
  edf_hdr.VERSION=H1(1:8);                          % 8 Byte  Versionsnummer
  edf_hdr.PID = deblank(H1(9:88));                  % 80 Byte local patient identification
  edf_hdr.RID = deblank(H1(89:168));                % 80 Byte local recording identification
  edf_hdr.T0=[str2num(H1(168+[7 8])) str2num(H1(168+[4 5])) str2num(H1(168+[1 2])) str2num(H1(168+[9 10])) str2num(H1(168+[12 13])) str2num(H1(168+[15 16])) ];
  
  edf_hdr.HeadLen = str2num(H1(185:192));  % 8 Byte  Length of Header
  edf_hdr.NRec = str2num(H1(237:244));     % 8 Byte  # of data records
  edf_hdr.Dur  = str2num(H1(245:252));     % 8 Byte  # duration of data record in sec
  edf_hdr.NS   = str2num(H1(253:256));     % 8 Byte  # of signals
  
  edf_hdr.Label      = char(fread(edf_hdr.FILE.FID,[16,edf_hdr.NS],'uint8=>char')');
  edf_hdr.Transducer = char(fread(edf_hdr.FILE.FID,[80,edf_hdr.NS],'uint8=>char')');
  edf_hdr.PhysDim    = char(fread(edf_hdr.FILE.FID,[ 8,edf_hdr.NS],'uint8=>char')');
  
  edf_hdr.PhysMin= str2num(char(fread(edf_hdr.FILE.FID,[8,edf_hdr.NS],'uint8=>char')'));
  edf_hdr.PhysMax= str2num(char(fread(edf_hdr.FILE.FID,[8,edf_hdr.NS],'uint8=>char')'));
  edf_hdr.DigMin = str2num(char(fread(edf_hdr.FILE.FID,[8,edf_hdr.NS],'uint8=>char')'));
  edf_hdr.DigMax = str2num(char(fread(edf_hdr.FILE.FID,[8,edf_hdr.NS],'uint8=>char')'));
  
  edf_hdr.PreFilt= char(fread(edf_hdr.FILE.FID,[80,edf_hdr.NS],'uint8=>char')');
  edf_hdr.SPR = str2num(char(fread(edf_hdr.FILE.FID,[8,edf_hdr.NS],'uint8=>char')'));  % samples per data record
  
  fseek(edf_hdr.FILE.FID,32*edf_hdr.NS,0);
  
  edf_hdr.SampleRate = edf_hdr.SPR / edf_hdr.Dur;
  edf_hdr.nSamples = unique(edf_hdr.NRec * edf_hdr.SPR);
  edf_hdr.Fs = unique(edf_hdr.SampleRate);

  edf_hdr.FILE.POS = ftell(edf_hdr.FILE.FID);
  if edf_hdr.NRec == -1                            % unknown record size, determine correct NRec
    fseek(edf_hdr.FILE.FID, 0, 'eof');
    endpos = ftell(edf_hdr.FILE.FID);
    edf_hdr.NRec = floor((endpos - edf_hdr.FILE.POS) / (sum(edf_hdr.SPR) * 2));
    fseek(edf_hdr.FILE.FID, edf_hdr.FILE.POS, 'bof');
  end

  % close the file
  fclose(edf_hdr.FILE.FID);

  %integrity check
  assert(length(edf_hdr.nSamples)==1,"Inconsistent SPRs")
  assert(length(edf_hdr.Fs)==1,"Inconsistent SamplingRates")
  
  if (length(edf_hdr.DigMin) ~= edf_hdr.NS)
    fprintf(2,'Warning OPENedf_hdr: Failing Digital Minimum\n');
    edf_hdr.DigMin = -(2^15)*ones(edf_hdr.NS,1);
  end
  if (length(edf_hdr.DigMax) ~= edf_hdr.NS)
    fprintf(2,'Warning OPENedf_hdr: Failing Digital Maximum\n');
    edf_hdr.DigMax = (2^15-1)*ones(edf_hdr.NS,1);
  end
  if (any(edf_hdr.DigMin >= edf_hdr.DigMax))
    fprintf(2,'Warning OPENedf_hdr: Digital Minimum larger than Maximum\n');
  end
  % check validity of PhysMin and PhysMax
  if (length(edf_hdr.PhysMin) ~= edf_hdr.NS)
    fprintf(2,'Warning OPENedf_hdr: Failing Physical Minimum, taking Digital Minimum instead\n');
    edf_hdr.PhysMin = edf_hdr.DigMin;
  end
  if (length(edf_hdr.PhysMax) ~= edf_hdr.NS)
    fprintf(2,'Warning OPENedf_hdr: Failing Physical Maximum, taking Digital Maximum instead\n');
    edf_hdr.PhysMax = edf_hdr.DigMax;
  end
