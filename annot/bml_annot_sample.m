function sample = bml_annot_sample(cfg, annot)

% BML_ANNOT_SAMPLE returns a random sample of rows
%
% Use as
%   sample = bml_annot_sample(annot);
%   sample = bml_annot_sample(cfg, annot);
%   sample = bml_annot_sample(cfg.n, annot);
%
% The first argument cfg is a configuration structure, which can contain
% the following field:
% cfg.n - integer: number of rows to select (defaults to 1)
% cfg.frac - float: fraction of rows to return 
% cfg.description - string: description of the output annot table
% cfg.groupby - cellstr indicating name of column of annot by which to group
%             the rows before sampling. If missing no grouping is
%             done.
% cfg.warn - bool: should warning be issued when not enough rows?
%
% Returns a annotation table with a random subset of rows

if nargin == 1
  annot = bml_annot_table(cfg,[],inputname(1));
  cfg = [];
elseif nargin == 2
  annot = bml_annot_table(annot,[],inputname(2));
else
  error('incorrect number of arguments in call to bml_annot_consolidate');
end

if ~isstruct(cfg)
    cfg = struct('n',cfg);
end

frac = bml_getopt(cfg,'frac',[]);
n = bml_getopt(cfg,'n',1);
groupby = bml_getopt(cfg,'groupby',[]);
warn = bml_getopt(cfg,'warn',true);

if isempty(annot)
  sample = annot;
  return
end


%ToDo: allow grouping by several variables
if isempty(groupby)
  annot.groupby_=ones(height(annot),1);
  groupby = {'groupby_'};
  groups={1};
else
	if sum(strcmp(annot.Properties.VariableNames, groupby))~=1
    error('groupby should match one (and only one) column of annot');
  end
  groups = unique(annot{:,groupby});
end

sample = table();
for g=1:numel(groups)
  if iscellstr(groups(g))
    annot_g = annot(strcmp(annot{:,groupby},groups(g)),:);
    g_name = groups{g};
  else
    annot_g = annot(annot{:,groupby}==groups{g},:);    
    g_name = num2str(groups{g});
  end
  
  ngt = height(annot_g);
  if ~isempty(frac)
    ng = round(frac*ngt);
  else
    ng = n;
  end
  
  if ng>ngt
    ng = ngt;
    if warn
        warning('group %s has only %i rows',g_name, ngt);
    end
  end
  
  sample_g = annot_g(randsample(height(annot_g),ng),:);
  sample = [sample; sample_g];
end

