function annot = bml_annot_consolidate(cfg, x)

% BML_ANNOT_CONSOLIDATE returns a consolidated annotation table
%
% Use as
%   annot = bml_annot_consolidate(cfg, annot1);
%
% The first argument cfg is a configuration structure, which can contain
% the following field:
% cfg.criterion - function handle: consolidation criteria. This function should
%             accept a table of candidate annotations to consolidate and 
%             return a true or false.  
% cfg.description - string: description of the output annot table
%
% Returns a annotation table with the folloing variables:
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

x=bml_annot_table(x,[],inputname(2));
description = ft_getopt(cfg,'description', ['cons_' x.Properties.Description]);
criterion = ft_getopt(cfg,'criterion',[]);

if ~isa(criterion, 'function_handle')
  error('''criterion'' should be a function handle');
end

i=1; j=1;
tmp=collapse_table_rows(x(1,:));
annot = cell2table(cell(0,width(tmp))); 
annot.Properties.VariableNames = tmp.Properties.VariableNames;

if height(x)<=1
  annot = collapse_table_rows(x);
  annot.id=[];
  annot = bml_annot_table(annot,description);
  return
end

while i<=height(x)
  if j==1 
    curr_s=collapse_table_rows(x(i,:));
  end
  
  merge_s = x(i:(i+j),:);
  
  if criterion(merge_s)
    curr_s = collapse_table_rows(merge_s);
    j = j + 1;
    if i + j > height(x)
      annot = [annot; curr_s];
      i = height(x)+1;
    end
  else
  	annot = [annot;curr_s];
    i = i + j;
    j = 1;
    if i == height(x) %adding last register
      curr_s = collapse_table_rows(x(i,:));
      annot = [annot; curr_s];
      i = height(x)+1;
    end
  end
end

annot.id=[];
annot = bml_annot_table(annot,description);





function collapsed = collapse_table_rows(merge_s)
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
  
vars = setdiff(merge_s.Properties.VariableNames,collapsed.Properties.VariableNames);
row=[];
for i=1:length(vars)
  uval = unique(merge_s.(vars{i}));
  if length(uval)==1
    row.(vars{i}) = uval;
  elseif iscell(uval)
    row.(vars{i}) = {[]};    
  else
    row.(vars{i}) = nan;
  end
end

collapsed = [collapsed, struct2table(row)];





