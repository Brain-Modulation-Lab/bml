 function bml_plb_singleplotTFR(cfg, TF)
% global SUBJECT TASK TLOCK SESSION TBASEL

% figure; hold on; 

% BML_SINGLEPLOTTFR is a thin wrapper over ft_singleplotTFR
% 
% cfg.events - table with events to be marked as vertical lines
% cfg.bands - indicates if cannonical bands should be indicated
%

% if ~isfield(cfg,'channel') || isempty(cfg.channel)
%   error('channel required');
% end

if ~isfield(cfg,'baseline') || isempty(cfg.baseline)
  error('baseline required');
end

if ~isfield(TF,'freq') || isempty(TF.freq)
  error('data.freq required');
end

events           = bml_getopt(cfg,'events',table());
bands            = bml_getopt(cfg,'bands',bml_get_canonical_bands());

statmask = bml_getopt_single(cfg, 'statmask', 'no');
savefig = bml_getopt_single(cfg, 'savefig', 'no');


cfg.channel         = bml_getopt(cfg,'channel', '');
cfg.parameter = 'powspctrm'; % what fieldtrip will look to plot

% bml_singleplotTFR(cfg_tmp, ft_freqdescriptives([], TF));
% bml_singleplotTFR(cfg, TF);


cfg.ylim         = bml_getopt_single(cfg,'ylim','maxmin');
cfg.xlim          = bml_getopt_single(cfg,'xlim', [-1 1]);
cfg.zlim          = bml_getopt_single(cfg,'zlim', [-1 1]);
cfg.title          = bml_getopt(cfg,'title', 'TFR');


cfg.colorbar     = bml_getopt_single(cfg,'colorbar','yes');
cfg.baselinetype = bml_getopt_single(cfg,'baselinetype','zscore');
cfg.hax = bml_getopt_single(cfg,'hax', gca());
cfg.robavg = bml_getopt_single(cfg, 'robavg', 'no');

cfg.baselinediagnostic          = bml_getopt(cfg,'baselinediagnostic', 'no');
cfg.showlabels   = 'no';	
cfg.showscale    = 'no';
cfg.box          = 'no';
cfg.masknans     = 'yes';

% %nyticks          = bml_getopt(cfg,'nyticks',5);
% foi              = data.freq;
% foi_idx          = 1:length(data.freq);
% data.freq        = foi_idx;

toilimbands      = [min(TF.time) max(TF.time)];

cfg.colorbar     = bml_getopt(cfg,'colorbar','yes');
cfg.xlabel     = bml_getopt(cfg,'xlabel','Time');
cfg.ylabel     = bml_getopt(cfg,'ylabel','Frequency [Hz]');


cfg.showlabels   = 'no';	
cfg.showscale    = 'no';
cfg.box          = 'no';
cfg.masknans     = 'yes';

if strcmp(statmask, 'yes') 
    stat = TF.stat; % have to save this separately since FT functions remove the field
end

% ensure that we have just one channel we're plotting
if size(TF.powspctrm, find(split(TF.dimord, '_')=="chan"))>1
    if cfg.channel==""
        error('Specify a channel to plot with cfg.channel');
    else
        cfgtmp = keepfields(cfg, 'channel');
        TF = ft_selectdata(cfgtmp, TF); % select a specific
    end
end

axes(cfg.hax);
% %% Plot with imagesc
% hfig = gcf; 
% % -- diagnostic baseline plot for this channel
% if cfg.baselinediagnostic=="yes"
% cfgtmp = []; 
% cfgtmp.latency = cfg.baseline; 
% TF_baseline = ft_selectdata(cfgtmp, TF);
% pow = squeeze(mean(TF_baseline.powspctrm, 4));
% pow = (pow - mean(pow, 1)) ./ mean(pow, 1); 
% % pow = pow ./ std(pow, [], 1); 
% pltidxs = round(logspace(log10(4), log10(width(pow)), 15)); 
% pow = pow(:, pltidxs); 
% freq = TF_baseline.freq(pltidxs); 
% % cmap = flip(autumn(61),1); % yellow -> red, with 61 colors (for 61 lines)
% % cmap = flip(cbrewer2('Oranges', 100), 1); cmap(1:20, :) = [];
% cmap = flip(cbrewer2('RdYlBu', width(pow)), 2); 
% trial = 1:height(pow); 
% figure('position',  [424         543        1767         795]); 
% hold on; colororder(cmap); % set(gca(), 'ColorOrder',cmap); 
% % set(gca, 'yscale', 'log');
% for ifreq = 1:width(pow)
%     plot(trial, pow(:, ifreq), 'LineWidth', 2, 'DisplayName', string(round(freq(ifreq)))); 
% end
% title(['Baseline diagnostic plot' cfg.title]); 
% xlabel('Trial #'); ylabel('Power (uV^2)'); 
% legend;
% yline(0, 'LineWidth',2, 'Color', 'k')
% end
% % -- diagnostic baseline plot for this channel
% figure(hfig)

if cfg.robavg=="yes"
    TF.powspctrm = spm_robust_average(TF.powspctrm, 1);
else
    TF = ft_freqdescriptives([], TF);
end

if ~strcmp(cfg.baseline, 'none')
    TF = ft_freqbaseline(cfg, TF);
end




imagesc(cfg.hax, TF.time, (TF.freq), (squeeze(TF.powspctrm)));
set(cfg.hax, 'ydir', 'normal');
set(cfg.hax, 'yscale', 'log'); 

ticks_wanted = [4,8,12,30,60,120,250];
yticks(cfg.hax, ticks_wanted); yticklabels(cfg.hax, ticks_wanted);

xline(cfg.hax, 0, 'LineWidth', 3); 


% add stat countours to the plot
if strcmp(statmask, 'yes') % plot statistically significant areas
    contour(cfg.hax, TF.time, TF.freq, squeeze(stat), 1, 'LineWidth', 3, 'Color', 'k'); 
end




% ft_singleplotTFR(cfg, );

% set(gca,'ytick',[])
% set(gca,'yticklabel',[])

% polycoeff = polyfit(log10(foi),foi_idx,1);

% if ~isempty(bands)
%   hold on
%   fstarts_idx = polyval(polycoeff,log10(max(bands.fstarts,min(foi))));
% 	fends_idx =  polyval(polycoeff,log10(min(bands.fends,max(foi))));
%   %fstarts_idx = dsearchn(foi',bands.fstarts)-0.5;
% 	%fends_idx = dsearchn(foi',bands.fends)+0.5;
%   midpoint_idx = 0.5.*(fstarts_idx + fends_idx);
%   yyaxis right
%   yticks(midpoint_idx)
%   yticklabels(bands.symbol)
% 	for i=1:height(bands)
%     fill(toilimbands(2) .* [1,1.05,1.05,1],...
%          [fstarts_idx(i),fstarts_idx(i),fends_idx(i),fends_idx(i)],...
%          hex2rgb(bands.color(i)),'EdgeColor','black','Marker','none');
%   end
% end
% 
% foi_ticks_wanted = [round(min(foi),1),4,8,12,30,60,120,250];
% foi_ticks_idx = polyval(polycoeff,log10(foi_ticks_wanted));
% 
% yyaxis left
% yticks(foi_ticks_idx)
% yticklabels(round(foi_ticks_wanted,2,'signif'))

% hold on
% if ~isempty(events)
%   if ~ismember('color',events.Properties.VariableNames)
%     events.color(:)={'#444444'};
%   end
% 	if ~ismember('starts_color',events.Properties.VariableNames)
%     events.starts_color=events.color;
%   end
% 	if ~ismember('ends_color',events.Properties.VariableNames)
%     events.ends_color=events.color;
%   end
%   if ~ismember('linestyle',events.Properties.VariableNames)
%     events.linestyle(:)={'-'};
%   end
% 
%   for i=1:height(events)
% 
%     if ~ismissing(events.starts_color(i))
%       plot(repmat(events.starts(i),[1,2]),[min(foi_idx)-0.5,max(foi_idx)],...
%         'Color',hex2rgb(events.starts_color{i}),'LineStyle',events.linestyle{i},...
%         'Marker','none');
%       if ismember('starts_error',events.Properties.VariableNames) && ~isnan(events.starts_error(i))
%         errorbar(events.starts(i),max(foi_idx),events.starts_error(i),'horizontal',...
%           'Color',hex2rgb(events.starts_color{i}),'Marker','none','CapSize',4)
%       end
%     end
%     if ~ismissing(events.ends_color(i))
%       plot(repmat(events.ends(i),[1,2]),[min(foi_idx)-0.5,max(foi_idx)],...
%         'Color',hex2rgb(events.ends_color{i}),'LineStyle',events.linestyle{i},...
%         'Marker','none');
%       if ismember('ends_error',events.Properties.VariableNames) && ~isnan(events.ends_error(i))
%         errorbar(events.ends(i),max(foi_idx),events.ends_error(i),'horizontal',...
%           'Color',hex2rgb(events.ends_color{i}),'Marker','none','CapSize',4)
%       end 
%     end
%   end
% end
% 
% 
% 
% 




colormap(cfg.hax, flipud(cbrewer2('RdBu')));
hC = colorbar(cfg.hax);
cl = get(cfg.hax, 'clim');
% clim(min(abs(cl))*[-1 1]);
if string(cfg.zlim)=="auto"
    prc = prctile(abs(TF.powspctrm(:)), 90); 
    clim(cfg.hax, [-prc, prc]); 
else 
clim(cfg.hax, cfg.zlim); % or set zlim
end
% caxis([-5 5]);

if strcmp(cfg.baselinetype, 'db')
cfg.zlabel = '[dB] Power wrt baseline';
elseif strcmp(cfg.baselinetype, 'relchange')
cfg.zlabel = '% change wrt baseline';
elseif strcmp(cfg.baselinetype, 'zscore')
cfg.zlabel = 'z-score wrt baseline';
else 
cfg.zlabel = '';
end
hC.Label.String = cfg.zlabel;
ylim(cfg.hax, [4 250]);

title(cfg.hax, cfg.title, 'Interpreter','none');
xlabel(cfg.hax, cfg.xlabel);
ylabel(cfg.hax, cfg.ylabel); 
xlim(cfg.hax, cfg.xlim);

% bands = [12 30; 
%          60 250]; 
% for ib = 1:height(bands)
%     hold on; 
% 
%     cfgtmp = [];
%     cfgtmp.frequency = bands(ib, :);
%     cfgtmp.avgoverfreq = 'yes'; 
%     TFband = ft_selectdata(cfgtmp, TF);
% 
%     t = TFband.time; 
% %     y = 5*(sin(2 * pi * 10 * (1:length(t))/length(t)));
%     y = squeeze(TFband.powspctrm);
% 
%     range1 = diff([-5 5]); 
%     range2 = diff(bands(ib, :)); 
% %     y = y * (range2 / range1); 
% %     yrange = max(y)-min(y); 
% %     ymean = mean(y); 
% 
%     y = (y-min(y)); 
%     y = y / max(y); 
%     y = exp(y) - exp(0.5); 
%     y = y * (range2/2); 
%     offset = exp(mean(log(bands(ib, :)))); 
%     y = y + offset; 
%     y = sgolayfilt(y, 3, 11); 
%     plot(t, y, 'w', 'linewidth', 3); plot(t, y, 'k', 'linewidth',2);
%     yline(offset); 
% end

% xlim([TBASEL(1) toi(2)]);
% rectangle('position', [TBASEL(1) 0 diff(TBASEL) diff(ylim())], 'FaceColor', 'w', 'EdgeColor', 'none')


set(cfg.hax, 'Layer', 'top')
box on

if strcmp(savefig, 'yes')
export_fig(cfg.path, '-m3',gcf);
% close(gcf);
end



end
