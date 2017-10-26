function annot=bml_annot_reorder_vars(cfg, x)

% BML_ANNOT_REORDER_VARS changes the order of vars in an annot table
%
% cfg.order - cell-array of strings: prefered order

vars = ft_getopt(cfg,'order',x.Properties.VariableNames);
isvars = ismember(vars,x.Properties.VariableNames);
vars = vars(isvars);
othervars = ~ismember(x.Properties.VariableNames, vars);
vars = [vars, x.Properties.VariableNames(othervars)];
annot = x(:,vars);

