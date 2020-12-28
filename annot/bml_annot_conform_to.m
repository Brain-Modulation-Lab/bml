function conformed = bml_annot_conform_to(template, annot)

% BML_ANNOT_CONFORM_TO conforms an annotation table to the shape of an other
%
% template - annot table to use as template for transformation
% annot - annot table to conform
%
% returns a conformed annot table

template_vars = template.Properties.VariableNames;
annot_vars = annot.Properties.VariableNames;

missing_vars = setdiff(template_vars,annot_vars);
for i=1:length(missing_vars)
  if iscellstr(template.(missing_vars{i}))
    annot.(missing_vars{i}) = repmat({''},height(annot),1);
  elseif iscell(template.(missing_vars{i}))
    annot.(missing_vars{i}) = repmat({nan},height(annot),1);
  else
    annot.(missing_vars{i}) = NaN(height(annot),1); 
  end
end

conformed = annot(:,template_vars);

%verifying format 
for i=1:width(conformed)
    if iscellstr(template{:,i}) && ~iscellstr(conformed{:,i})
        if isvector(conformed{:,i}) || ismatrix(conformed{:,i})
            conformed.(i) = cellstr(num2str(conformed.(i)));
        end
    end
end



