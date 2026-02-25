function  varargout = plot_ERNAwaveform(cfg,data)

% get cfg fields
nbursts_plot = cfg.nburst_plots;
timeburst = cfg.timeburst;
time = cfg.time;
erna_cycles_annot = cfg.erna_cycles_annot;
run_annot = cfg.run_annot;
stim_vec = cfg.stim_vec;
time_rel = cfg.time_rel;
Cmap = cfg.Cmap;

% extract useful data
if time_rel
    timeburst = timeburst - run_annot.starts;
end

stim_run = run_annot.Amp;% 3.5 mA most of the time accoridng to protocol
data_ofint = data(stim_vec == stim_run,:);

% plot

if isempty(data_ofint)
    figure('position',[ 200 200 800 400],'visible','off')
    varargout{1} = gcf;
    fprintf('No data to show in this run %d \n',run_annot.Run)
    return
end

figure('position',[ 200 200 800 400],'visible','off')
tiledlayout(1,2)
nexttile(1,[1 1])
imagesc(timeburst,time,data')
hold on
scatter(timeburst(erna_cycles_annot.burst_id(erna_cycles_annot.cycle_id == 1)),erna_cycles_annot.peak_time(erna_cycles_annot.cycle_id == 1),2,'r','filled')
scatter(timeburst(erna_cycles_annot.burst_id(erna_cycles_annot.cycle_id == 1)),erna_cycles_annot.trough_time(erna_cycles_annot.cycle_id == 1),2,'b','filled')
scatter(timeburst(erna_cycles_annot.burst_id(erna_cycles_annot.cycle_id == 2)),erna_cycles_annot.peak_time(erna_cycles_annot.cycle_id == 2),2,'r','filled')

set(gca,'YDir','normal')
xlabel(' Time burst [s]')
ylabel('Time after last pulse [s]')
colormap(Cmap)
cb = colorbar;
cb.Label.String = 'Erna amplitude [\muV]';
box off

yyaxis right
stairs(timeburst,stim_vec,'linewidth',2)
ylabel(' Stim. [mA]')
ylim([0 stim_run + .2])

nexttile(2,[1 1])
plot(time,mean(data_ofint),'color','k','linewidth',1.5)
xlim([0 0.015])
xlabel('Time after last pulse [s]')
ylabel('ERNA [\muV]')
hold on
% overlap first 20 burst and last 20 bursts
plot(time, mean(data_ofint(10 + (1 : nbursts_plot),:)),'linewidth',1.5)
plot(time, mean(data_ofint((end - nbursts_plot + 1) : end,:)),'linewidth',1.5)
legend({'all bursts',sprintf('first %d',nbursts_plot),sprintf('last %d',nbursts_plot)},'location','best')
box off

sgtitle(sprintf('Stim: %s (Sensing: %s-%s) [%1.1f mA, %1.1f Hz] [stimScan Run=%d] \n', string(run_annot.StimC), ...
    string(run_annot.SenseP), string(run_annot.SenseN), run_annot.Amp, ...
    run_annot.Freq, run_annot.Run))


if numel(nargout) == 1
    varargout{1} = gcf;
end
