function  varargout = plot_ERNAproperties(cfg,f,PXX)

% get cfg fields
erna_annot = cfg.erna_annot;
run_annot = cfg.run_annot;
stim_vec = cfg.stim_vec;

time_rel = cfg.time_rel;
Cmap = cfg.Cmap;

if height(erna_annot) == 0 || isempty(erna_annot)
    f1 = figure('position',[200 200 1000 500],'visible','off');
    f2 = figure('position',[200 200 600 200],'visible','off');
    varargout{1} = [f1 f2];
    return
end

bursts = unique(erna_annot.burst_id);
% 3.5 mA most of the time accoridng to protocol
timeburst = cfg.timeburst;
if time_rel
    timeburst = timeburst - run_annot.starts;
end


f1 = figure('position',[200 200 1000 500],'visible','off');
tiledlayout(2,3)
nexttile(1,[1 1])
scatter(timeburst(bursts), erna_annot.amplitude,25,'k','filled')
xlabel(' Time burst [s]')
ylabel(' ERNA amplitude [\muV] ')
yyaxis right
stairs(timeburst,stim_vec,'linewidth',2)
ylabel(' Stim. [mA]')
box off
ylim([0 run_annot.Amp + .2])

nexttile(2,[1 1])
scatter(timeburst(bursts), erna_annot.latency,25,'k','filled')
xlabel(' Time burst [s]')
ylabel(' ERNA latency [ms] ')
yyaxis right
stairs(timeburst,stim_vec,'linewidth',2)
ylabel(' Stim. [mA]')
box off
ylim([0 run_annot.Amp + .2])

nexttile(3,[1 1])
scatter(timeburst(bursts), erna_annot.frequency,25,'k','filled')
xlabel(' Time burst [s]')
ylabel(' ERNA frequency [Hz] ')
yyaxis right
stairs(timeburst,stim_vec,'linewidth',2)
ylabel(' Stim. [mA]')
box off
ylim([0 run_annot.Amp + .2])

nexttile(4,[1 1])
scatter(timeburst(bursts), erna_annot.ncycles,25,'k','filled')
xlabel(' Time burst [s]')
ylabel(' # ERNA cycles ')
yyaxis right
stairs(timeburst,stim_vec,'linewidth',2)
ylabel(' Stim. [mA]')
box off
ylim([0 run_annot.Amp+ .2])

nexttile(5,[1 1])
scatter(timeburst(bursts), erna_annot.damping,25,'k','filled')
xlabel(' Time burst [s]')
ylabel(' ERNA damping [a.u] ')
yyaxis right
stairs(timeburst,stim_vec,'linewidth',2)
ylabel(' Stim. [mA]')
box off
ylim([0 run_annot.Amp+ .2])

nexttile(6,[1 1])
% surf([annot.frequency_power annot.frequency_power], [10*log10(annot.amplitude_power) 10*log10(annot.amplitude_power)], [timeburst_rel(bursts)' timeburst_rel(bursts)'], ...  % Reshape and replicate data
%  'FaceColor', 'none', ...    % Don't bother filling faces with color
%  'EdgeColor', 'interp', ...  % Use interpolated color for edges
%  'LineWidth', 2);
% view(2)
%
scatter3(erna_annot.latency,erna_annot.frequency, erna_annot.amplitude,  35,timeburst(bursts)','filled')
xlabel(' ERNA latency [s] ')
ylabel(' ERNA Frequency [Hz] ')
zlabel(' ERNA amplitude [\muV] ')
colormap(Cmap)
cb = colorbar;
cb.Label.String = 'Time burst [s]';


sgtitle(sprintf('Stim: %s (Sensing: %s-%s) [%1.1f mA, %1.1f Hz] [stimScan Run=%d] \n', string(run_annot.StimC), ...
    string(run_annot.SenseP), string(run_annot.SenseN), run_annot.Amp, ...
    run_annot.Freq, run_annot.Run))



f2 = figure('position',[200 200 600 200],'visible','off');
tiledlayout(1,3)

nexttile(1,[1 1])
imagesc(timeburst(bursts),f,10*log10(PXX))
set(gca,'YDir','normal')
ylim([300 600])
clim([-10 10])
colormap(Cmap)
cb = colorbar;
cb.Label.String = 'Erna Amplitude [dB]';
hold on
scatter(timeburst(bursts),erna_annot.frequency_power,15,'r','filled')
scatter(timeburst(bursts),erna_annot.frequency,15,'b','filled')
xlabel(' Time burst [s]')
ylabel(' ERNA Frequency [Hz] ')
box off


nexttile(2,[1 1])
plot(f,10*log10(PXX),'linestyle','--','color','k','linewidth',.3)
box off
hold on
scatter(erna_annot.frequency_power,10*log10(erna_annot.amplitude_power),'r','filled')
xlim([300 600])
xlabel(' ERNA Frequency [Hz]')
ylabel(' ERNA amplitude [dB] ')

nexttile(3,[1 1])
% surf([annot.frequency_power annot.frequency_power], [10*log10(annot.amplitude_power) 10*log10(annot.amplitude_power)], [timeburst_rel(bursts)' timeburst_rel(bursts)'], ...  % Reshape and replicate data
%  'FaceColor', 'none', ...    % Don't bother filling faces with color
%  'EdgeColor', 'interp', ...  % Use interpolated color for edges
%  'LineWidth', 2);
% view(2)
%
scatter(erna_annot.frequency_power, 10*log10(erna_annot.amplitude_power),35,timeburst(bursts)','filled')
xlabel(' ERNA Frequency [Hz] ')
ylabel(' ERNA amplitude [dB] ')
colormap(Cmap)
cb = colorbar;
cb.Label.String = 'Time burst [s]';

sgtitle(sprintf('Stim: %s (Sensing: %s-%s) [%1.1f mA, %1.1f Hz] [stimScan Run=%d] \n', string(run_annot.StimC), ...
    string(run_annot.SenseP), string(run_annot.SenseN), run_annot.Amp, ...
    run_annot.Freq, run_annot.Run))


if numel(nargout) == 1
    varargout{1} = [f1 f2];
end