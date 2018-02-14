function bml_praat(varargin)

% BML_PRAAT opens FT_DATATYPE_RAWs in praat
%
% Use as
%   bml_praat(raw1, raw2)
%   bml_praat('name1', raw1, 'name2', raw2)
%
% where raw1, raw2 ... rawN are the FT_DATATYPE_RAWs you wanto to open 
%
% If no name is provided, the praat objects will be named r<R>t<T>_<channel_name>, where <R> is the
% index of the FT_DATATYPE_RAW in the call to bml_praat, <T> is the trial 
% number and <channel_name> is the name of the label of the channel.
%
% If a name is provided, the praat objects will be named <name>_t<T>_<channel_name>. 
%
% Opens a new praat window
%

%saving files to temp directory
recycle('off');
tdir=[tempdir 'bml_praat'];

%deleting previous wavs if any
if(exist(tdir,'dir')==7) %7 -> folder
  wavs = dir(fullfile(tdir, '*.wav'));
  for k = 1 : length(wavs)
    delete(fullfile(tdir, wavs(k).name));
  end
else
  mkdir(tdir);
end

%sorting raws and names from varargin
names={};
raws={};
waslastname=false;
for i=1:numel(varargin)
  if isa(varargin{i},'string') || isa(varargin{i},'char') 
    assert(~waslastname,'two consecutive names in argument %i', i);
    names = [names {strcat(varargin{i},'_')}];
    waslastname=true;  
  elseif iscellstr(varargin{i})
    assert(numel(varargin{i})==1,'invalid name parameter %i',i);
    assert(~waslastname,'two consecutive names in argument %i', i);
    names = [names {strcat(varargin{i}{1},'_')}];
    waslastname=true; 
  elseif isstruct(varargin{i})
    if ~waslastname; names = {names{:} ''}; end
    raws = [raws {varargin{i}}];   
    waslastname=false;
  else
    error('unknown type for argument %i',i);
  end
end

names = strrep(deblank(names),' ','_');

%wavs={};
rf=['%0' num2str(ceil(log10(numel(raws)))+1) 'd']; 
cmd ='';
for i=1:numel(raws)
  tf=['%0' num2str(ceil(log10(numel(raws{i}.trial)))+1) 'd']; 
  for t=1:numel(raws{i}.trial)
    for c=1:numel(raws{i}.label)
      wfn=char(strrep(raws{i}.label{c}," ","_"));
      if isempty(char(names{i}))
        wfn=[tdir filesep 'r' num2str(i,rf) 't' num2str(t,tf) '_' wfn '.wav'];
      else
        wfn=[tdir filesep char(names{i}) 't' num2str(t,tf) '_' wfn '.wav'];
      end
      v=raws{i}.trial{t}(c,:);
      
      if ismember({'fsample'},fields(raws{i}))
        Fs = round(raws{i}.fsample,0);
      else
        Fs = round(1/mean(diff(raws{i}.time{1})),0);
      end
      
      audiowrite(wfn,v./max(abs(v)),Fs);
      %wavs=[wavs,wfn];
      cmd = [cmd wfn ' '];
    end
  end
end


%os specific determination of praat path
if ismac()
  %using open command in mac
  cmd = ['open -a praat ' cmd];
elseif isunix()
  search_dirs={'/usr/local/bin'};
  [~,cmdout]=system('which praat');
  if isempty(cmdout)  
    %cheking for praat in seach_dirs
    indx=find(cellfun(@(x)exist([x filesep 'praat'],'file')==2,search_dirs),1);
    if isempty(indx)
      warning('make sure praat is in your path')    
    else
      setenv('PATH', [search_dirs{indx} ':' getenv('PATH')]);   
    end
  end
  cmd = ['praat --open ' cmd '&'];
else
  cmd = ['praat --open ' cmd '&'];  
  warning('make sure praat is in your path. !echo $PATH')
end

system(cmd);


