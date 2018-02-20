function [ref,U] = bml_rereference(cfg,raw)

% BML_REREFERENCE applies re-referencing scheme to raw
%
% Use as
%   [ref,U] = bml_rereference(cfg,raw)
%
% cfg.label - Nx1 cellstr with labels. Defaults to raw.label
% cfg.group - Nx1 integer array identifying groups of electrodes
%   contacts of same group are re-referenced together
%   values <=0 and nans are not re-referenced. 
%   If not specified, groups are defined by string before underscore '_'
%   (i.e. ecog_*, micro_*, macro_*, audio_*, envaudio_*, etc)
% cfg.method - string, method to be implemented
%   'CAR' or 'common', common average referencing (default)
%   'LAR' or 'local', local average referencing
%   'VAR' or 'variable', variable average referencing
%
% raw - ft_datatype_raw to be re-referenced
% 
% Returns
% ref - ft_datatype_raw with re-referenced data
% U - double, unmixing matrix. ref = U * raw

assert(isstruct(raw),"invalid raw");
assert(all(ismember({'trial','time','label'},fieldnames(raw))),"invalid raw");

label     = bml_getopt(cfg,'label',raw.label);
group     = bml_getopt(cfg,'group');
method    = bml_getopt_single(cfg,'method','CAR');

%inferring groups from labels
if isempty(group)
  sl=split(label,'_');
  sl=sl(:,1);
  usl=unique(sl);
  group = bml_map(sl,usl,1:length(usl));
end

%assigning orphan raw labels to null group
in=ismember(raw.label,label);
if ~all(in)
  label = [label;raw.label(~in)];
  group = [group; zeros(sum(~in),1)];
end

%re-ordering group to match raw.label
group = bml_map(raw.label,label,group);
label = raw.label;

%creating null group
group(ismissing(group))=0;
group(group<=0)=0;
g0 = sum(group<=0);

%keeping original order
[g,g_idx]=sort(group);
ug = unique(g);
[N,~] = histc(g,ug);

%creating blocks
if ismember(method,{'CAR','common'})
  U_blocks=cellfun(@bml_comavgref_matrix,num2cell(N),'UniformOutput',false);
elseif ismember(method,{'LAR','local'})
  U_blocks=cellfun(@bml_locavgref_matrix,num2cell(N),'UniformOutput',false);
elseif ismember(method,{'VAR','variable'})
  warning('Using experimental method VAR, susceptible to high amplitude artifacts')
  
  %calculating variance-covariance matrix
  cfg=[];
  cfg.covariance = 'yes';
  cfg.vartrllength = 2;
  tl_raw=ft_timelockanalysis(cfg,raw);
  
  %grouping matrix into blocks
  COVs = cell(length(ug),1);
  for i=1:length(ug)
    COVs{i,1}=tl_raw.cov(g_idx(g==ug(i)),g_idx(g==ug(i)));
  end
  
  %creating blocks
  U_blocks=cellfun(@bml_varavgref_matrix,COVs,'UniformOutput',false);
  
else
  error('unknown method')
end

%replacing block by identity for null group
if g0 > 0
  U_blocks{1} = eye(N(1));
end

%joining blocks
U = blkdiag(U_blocks{:});
U(g_idx,g_idx) = U;
%image(U,'CDataMapping','scaled')
  
%applying unmixing matrix to data
ref = bml_apply(@(x) U*x, raw);
  

