function bml_plot_raster(cfg, raw)

% BML_PLOT_RASTER plots a raster for each trial
%
% Use as
%   bml_plot_raster(cfg, raw);
%   bml_plot_raster(raw);
%
% The first argument cfg is a configuration structure, which can contain
% the following field:
% cfg.trial - 
% cfg.trial_name - string. defualts to 'trial'
% cfg.panels - length 2 integer vector specifying panel's columns and rows
% cfg.colorbar - bool

if nargin==1
  raw=cfg;
  cfg=[];
elseif nargin~=2
  error('incorrect number of argumens in call to bml_plot_raster')
end

panels = bml_getopt(cfg,'panels',[]);
colbar = bml_getopt(cfg,'colorbar',false);
trial_name = bml_getopt_single(cfg,'trial_name','trial');

hax = gca() ;
set(hax, 'TickLabelInterpreter', 'none'); 

T = numel(raw.trial);
if isempty(panels)
  panels = ceil(sqrt(T));
  panels = [panels, ceil(T/panels)];
end

for t=1:T
  subplot(panels(1),panels(2),t);
  image(raw.trial{t},'CDataMapping','scaled');
  title([trial_name,' ',num2str(t)]);
  if colbar; colorbar(); end

  nchans = size(raw.trial{t}, 1); 
  if nchans < 10
      yticks(1:10); yticklabels(raw.label(1:10));
  else
      yticks(1:round(nchans/10):nchans); 
      yticklabels(raw.label(1:round(nchans/10):nchans));
  end

end
