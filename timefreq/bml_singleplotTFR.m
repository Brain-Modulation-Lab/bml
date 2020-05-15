function bml_singleplotTFR(cfg, data)

% BML_SINGLEPLOTTFR is a thin wrapper over ft_singleplotTFR
% 
% cfg.events - table with events to be marked as vertical lines
% cfg.bands - indicates if cannonical bands should be indicated
%

if ~isfield(cfg,'channel') || isempty(cfg.channel)
  error('channel required');
end

if ~isfield(cfg,'baseline') || isempty(cfg.baseline)
  error('baseline required');
end

if ~isfield(data,'freq') || isempty(data.freq)
  error('data.freq required');
end

name =   {'delta',   'theta',  'alpha',   'beta','low gamma','high gamma'}';
symbol = {'\delta', '\theta', '\alpha',  '\beta', '\gamma_L','\gamma_H'}';
fstarts = [     1,         4,        8,       12,         30,          60]';
fends =   [     4,         8,       12,       30,         60,         250]';
color = {'#EDF8FB','#BFD3E6','#9EBCDA','#8C96C6',  '#8856A7',   '#810F7C'}'; %ColorBrewer BuPu_6
cannonical_bands = table(name,fstarts,fends,color,symbol);
clear name fstarts fends color symbol; 

events           = bml_getopt(cfg,'events',table());
bands            = bml_getopt(cfg,'bands',cannonical_bands);

%nyticks          = bml_getopt(cfg,'nyticks',5);
foi              = data.freq;
foi_idx          = 1:length(data.freq);
data.freq        = foi_idx;

toilimbands      = [min(data.time) max(data.time)];

cfg.ylim         = bml_getopt(cfg,'ylim','maxmin');
cfg.colorbar     = bml_getopt(cfg,'colorbar','yes');

cfg.baselinetype = 'db'; 
cfg.showlabels   = 'no';	
cfg.showscale    = 'no';
cfg.box          = 'no';
cfg.masknans     = 'yes';

ft_singleplotTFR(cfg, data);

set(gca,'ytick',[])
set(gca,'yticklabel',[])

polycoeff = polyfit(log10(foi),foi_idx,1);

if ~isempty(bands)
  hold on
  fstarts_idx = polyval(polycoeff,log10(max(bands.fstarts,min(foi))));
	fends_idx =  polyval(polycoeff,log10(min(bands.fends,max(foi))));
  %fstarts_idx = dsearchn(foi',bands.fstarts)-0.5;
	%fends_idx = dsearchn(foi',bands.fends)+0.5;
  midpoint_idx = 0.5.*(fstarts_idx + fends_idx);
  yyaxis right
  yticks(midpoint_idx)
  yticklabels(bands.symbol)
	for i=1:height(bands)
    fill(toilimbands(2) .* [1,1.05,1.05,1],...
         [fstarts_idx(i),fstarts_idx(i),fends_idx(i),fends_idx(i)],...
         hex2rgb(bands.color(i)),'EdgeColor','black','Marker','none');
  end
end

foi_ticks_wanted = [round(min(foi),1),4,8,12,30,60,120,250];
foi_ticks_idx = polyval(polycoeff,log10(foi_ticks_wanted));

yyaxis left
yticks(foi_ticks_idx)
yticklabels(round(foi_ticks_wanted,2,'signif'))

hold on
if ~isempty(events)
  if ~ismember('color',events.Properties.VariableNames)
    events.color(:)={'#444444'};
  end
	if ~ismember('starts_color',events.Properties.VariableNames)
    events.starts_color=events.color;
  end
	if ~ismember('ends_color',events.Properties.VariableNames)
    events.ends_color=events.color;
  end
  if ~ismember('linestyle',events.Properties.VariableNames)
    events.linestyle(:)={'-'};
  end
  
  for i=1:height(events)
    
    if ~ismissing(events.starts_color(i))
      plot(repmat(events.starts(i),[1,2]),[min(foi_idx)-0.5,max(foi_idx)],...
        'Color',hex2rgb(events.starts_color{i}),'LineStyle',events.linestyle{i},...
        'Marker','none');
      if ismember('starts_error',events.Properties.VariableNames) && ~isnan(events.starts_error(i))
        errorbar(events.starts(i),max(foi_idx),events.starts_error(i),'horizontal',...
          'Color',hex2rgb(events.starts_color{i}),'Marker','none','CapSize',4)
      end
    end
    if ~ismissing(events.ends_color(i))
      plot(repmat(events.ends(i),[1,2]),[min(foi_idx)-0.5,max(foi_idx)],...
        'Color',hex2rgb(events.ends_color{i}),'LineStyle',events.linestyle{i},...
        'Marker','none');
      if ismember('ends_error',events.Properties.VariableNames) && ~isnan(events.ends_error(i))
        errorbar(events.ends(i),max(foi_idx),events.ends_error(i),'horizontal',...
          'Color',hex2rgb(events.ends_color{i}),'Marker','none','CapSize',4)
      end 
    end
  end
end

