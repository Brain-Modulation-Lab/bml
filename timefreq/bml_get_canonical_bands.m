function bands = bml_get_canonical_bands(flim)

% returns table with canonical bands


name =   {'delta',   'theta',  'alpha',   'beta','low gamma','high gamma'}';
symbol = {'\delta', '\theta', '\alpha',  '\beta', '\gamma_L','\gamma_H'}';
fstarts = [     1,         4,        8,       12,         30,          60]';
fends =   [     4,         8,       12,       30,         60,         250]';
color = {'#EDF8FB','#BFD3E6','#9EBCDA','#8C96C6',  '#8856A7',   '#810F7C'}'; %ColorBrewer BuPu_6

if exist('flim','var')
  fstarts = max(fstarts,flim(1));
	fstarts = min(fstarts,flim(2));
  fends = max(fends,flim(1));
	fends = min(fends,flim(2));
end

bands = table(name,fstarts,fends,color,symbol);
clear name fstarts fends color symbol; 


