function roi=bml_roi_table(x, description, x_var_name)

% BML_ROI_TABLE transforms a table into an ROI table [internal]
%
% Use as
%   annot=bml_roi_table(x)
%   annot=bml_roi_table(x, description)
%   annot=bml_roi_table(x, [], x_var_name)
%
% ROI or Regions Of Interest are annotations with file coordinates.
%
% x - table: should contains 'starts','ends','folder','name','nSamples','Fs' 
% description - string: description of the ROI table
% x_var_name - string: name of the variable used for the ROI table, as
%     returned by inputname(). Useful for anidated calls.
%
% returns a table with variables:
%   id: integer identification number of the synchronized file chunk
%   starts: start time in seconds from midnight of the represented signal
%   ends: end time in seconds from midnight of the represented signal
%   duration: duration in seconds as calculated by ends - starts
%   s1: first sample number of synchronization coordinate
%   t1: midpoint time of sample s1. Note that if s1==1 => t1=starts+0.5/Fs
%   s2: last sample number of synchronization coordinate
%   t2: midpoint time of sample s2. Note that if s2==end => t2=ends-0.5/Fs
%   folder: path to folder with file
%   name: file name. Note that several each file can have several file
%         chunks, i.e. several rows in this table 
%   nSamples: integer total number of samples of the file
%   filetype: 
%   chantype: 

REQUIRED_VARS = {'folder','name','nSamples','Fs'};
RETURNED_VARS = {'id','starts','ends','duration','s1','t1','s2','t2',...
                'folder','name','nSamples','Fs','filetype','chantype'};

assert(istable(x),"Table required as first argumrnt");              
              
if ~exist('description','var') || isempty(description)
  if isempty(x.Properties.Description)
    if exist('x_var_name','var')
      description=x_var_name;
    else
      description=inputname(1);
    end
  else
    description=x.Properties.Description;
  end
end

roi=bml_annot_table(x,description);

if ~all(ismember(REQUIRED_VARS, roi.Properties.VariableNames))
  error(['table ''x'' requires variables ' strjoin(REQUIRED_VARS,', ')])
end

if ~all(ismember({'s1','t1'}, roi.Properties.VariableNames))
  roi.s1=ones(height(roi),1);
  roi.t1=roi.starts + 0.5 ./ roi.Fs;
end
if ~all(ismember({'s2','t2'}, roi.Properties.VariableNames))
  roi.s2=roi.nSamples;
  roi.t2=roi.ends - 0.5 ./ roi.Fs;
end

if ~ismember('chantype', roi.Properties.VariableNames)
  roi.chantype=repmat({'all'},height(roi),1);
end

if ~ismember('filetype', roi.Properties.VariableNames)
  %ToDo should probably identify filetype from filename
  roi.chantype=repmat({'unknown'},height(roi),1);
end
roi = bml_annot_reorder_vars(roi, RETURNED_VARS);
