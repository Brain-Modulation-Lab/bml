function [clr, idx] = bml_value2color(value, range, cmap)
% BML_VALUE2COLOR takes a value (scalar or vector), range that encompasses that value, and a 
% color map. It returns the color that corresponds to the location of the
% value within the range. 
%
%
% returns a nx3 matrix of color values

nclr = size(cmap, 1); 

perc = (value - range(1))./(diff(range)); 

idx = round(perc*(nclr-1) + 1); 

clr = cmap(idx, :); 

end