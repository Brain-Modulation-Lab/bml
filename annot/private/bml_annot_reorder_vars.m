function annot=bml_annot_reorder_vars(x, vars)

% BML_ANNOT_REORDER_VARS changes the order of vars in an annot table

isvars = ismember(vars,x.Properties.VariableNames);
vars = vars(isvars);
othervars = ~ismember(x.Properties.VariableNames, vars);
vars = [vars, x.Properties.VariableNames(othervars)];
annot = x(:,vars);

