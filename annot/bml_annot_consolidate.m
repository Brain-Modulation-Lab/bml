function cons = bml_annot_consolidate(cfg, annot)

% BML_ANNOT_CONSOLIDATE returns a consolidated annotation table
%
% Use as
%   cons = bml_annot_consolidate(cfg, annot);
%
% The first argument cfg is a configuration structure, which can contain
% the following field:
% cfg.criterion - function handle: consolidation criteria. This function should
%             accept a table of candidate annotations to consolidate and 
%             return a true or false.  
% cfg.description - string: description of the output annot table
% cfg.additive - cellstr with names of variables to be treated as additive 
%             defaults to empty
% cfg.groupby - cellstr indicating name of column of annot by which to group
%             the rows before consolidating. If missing no grouping is
%             done.
%
% Returns a annotation table with the folloing variables:
%   cons_duration - sum of the consolidated durations
%   id_starts - first original id of the consolidated row
%   id_ends - last original id of the consolidated row
%   cons_n - number of consolidated rows
%   cons_group - consolidation group id, only if groupby was specified
% 
% EXAMPLES
% ========
%
% %detecting stretches of constant depth in neuroomega
% cfg=[];
% cfg.criterion = @(x) (length(unique(x.depth))==1) && (abs((max(x.ends)-min(x.starts))-sum(x.duration))<10e-3);
% neuro_cons_depth = bml_annot_consolidate(cfg,info_neuroomega);
% 
% %grouping annotations in fours
% cfg=[];
% cfg.criterion = @(x) height(x)<=4
% grouped_annot = bml_annot_consolidate(cfg,annot);

annot = bml_annot_table(annot,[],inputname(2));

description = bml_getopt(cfg,'description', ['cons_' annot.Properties.Description]);
criterion   = bml_getopt(cfg,'criterion',[]);
additive    = bml_getopt(cfg,'additive',{});
groupby     = bml_getopt(cfg,'groupby',[]);

if ~isa(criterion, 'function_handle')
  error('''criterion'' should be a function handle');
end

%ToDo: allow grouping by several variables
if isempty(groupby)
  annot.cons_group(:)=1;
  groupby = {'cons_group'};
  groups={1};
else
	if ~any(strcmp(annot.Properties.VariableNames, groupby))
    error('groupby should match a column of annot');
  end
  groups = unique(annot{:,groupby});
end

cons = table();
for g=1:numel(groups)
  if iscellstr(groups(g))
    annot_g = annot(strcmp(annot{:,groupby},groups(g)),:);
  else
    annot_g = annot(annot{:,groupby}==groups{g},:);    
  end
  
  i=1; j=1;
  tmp=collapse_table_rows(annot_g(1,:),additive);
  cons_g = cell2table(cell(0,width(tmp))); 
  cons_g.Properties.VariableNames = tmp.Properties.VariableNames;

  if height(annot_g)<=1
    cons_g = collapse_table_rows(annot_g,additive);
    cons_g.id=[];
    cons_g = bml_annot_table(cons_g,description);
    return
  end

  while i<=height(annot_g)
    if j==1 
      curr_s=collapse_table_rows(annot_g(i,:),additive);
    end

    merge_s = annot_g(i:(i+j),:);

    if criterion(merge_s)
      curr_s = collapse_table_rows(merge_s,additive);
      j = j + 1;
      if i + j > height(annot_g)
        cons_g = [cons_g; curr_s];
        i = height(annot_g)+1;
      end
    else
      cons_g = [cons_g;curr_s];
      i = i + j;
      j = 1;
      if i == height(annot_g) %adding last register
        curr_s = collapse_table_rows(annot_g(i,:),additive);
        cons_g = [cons_g; curr_s];
        i = height(annot_g)+1;
      end
    end
  end
  cons = [cons; cons_g];
end
cons.id=[];
cons = bml_annot_table(cons,description);



function collapsed = collapse_table_rows(merge_s,additive)
%
% Private function. Collapses a table to a record

collapsed = table(...
  min(merge_s.starts),...
  max(merge_s.ends),...
  sum(merge_s.duration),...
  min(merge_s.id),...
  max(merge_s.id),...
  length(merge_s.id),...
  'VariableNames',{'starts','ends','cons_duration','id_starts','id_ends','cons_n'});
  
vars = setdiff(merge_s.Properties.VariableNames,[collapsed.Properties.VariableNames,additive]);
row=[];
for i=1:length(vars)
  uval = unique(merge_s.(vars{i}));
  if length(uval)==1
    row.(vars{i}) = uval;
  elseif iscell(uval)
    row.(vars{i}) = {[]};   
  elseif isa(uval,'datetime')
    row.(vars{i}) = NaT;
  else
    row.(vars{i}) = nan;
  end
end

%dealing with additive vars
for i=1:length(additive)
  uval = sum(merge_s.(additive{i}));
  row.(vars{i}) = uval;
end

collapsed = [collapsed, struct2table(row)];





