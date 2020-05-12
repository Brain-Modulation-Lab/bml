function desc = bml_annot_describe(cfg,annot)

% BML_ANNOT_DESCRIBE returns a table containing a description of each
% numeric column of annot. 
%
% Use as
%   desc = bml_annot_describe(cfg,annot)
%   desc = bml_annot_describe(annot)

if nargin == 1
  annot = cfg;
  cfg=[];
end

stats = {'mean','median','std',@(x)bml_robust_std(x'),'min','max','numel'};
groupby = bml_getopt(cfg, 'groupby', []);

colsel = varfun(@isnumeric,annot,'output','uniform');
if ~isempty(groupby)
  colsel = colsel |  ismember(annot.Properties.VariableNames,groupby);
end

desc1 = grpstats(annot(:,colsel),groupby,stats);
desc1.Properties.VariableNames = strrep(desc1.Properties.VariableNames,'Fun4','rstd');
sdesc = stack(desc1,setdiff(desc1.Properties.VariableNames,groupby),...
  'NewDataVariableName','value','IndexVariableName','fun_var');
sdesc.fun_var = cellstr(sdesc.fun_var);
sdesc = sdesc(~strcmp(sdesc.fun_var,'GroupCount'),:);
[fun,var]=strtok(sdesc.fun_var,'_');
var = strip(var,'left','_');
sdesc.fun = fun;
sdesc.variable = var;
sdesc.fun_var=[];
desc=unstack(sdesc,'value','fun');










