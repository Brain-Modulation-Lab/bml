function [ranking_prop,varargout] = get_ERNAranking(cfg,data)


electrode = cfg.electrode;
electrode_ref = cfg.electrode_ref;

if isempty(electrode_ref) || isempty(electrode)
    return
end

burst_limit = cfg.burst_limit;
bursts = cfg.bursts;

tmp = data(:,1:burst_limit);
tmp(isnan(tmp)) = 0;

[~,idx_sort] = sort(tmp,'descend');


if any(strcmpi(electrode,electrode_ref))
    idx_StimC = find(strcmpi(electrode,electrode_ref));
else % handle directional leads cases
    idx_StimC = find(cellfun(@(x) contains(electrode_ref,x),electrode));
    idx_StimC = idx_StimC + [0:2];
end
Cmap = linspecer(3);

ranking_prop = arrayfun(@(x) mean(idx_sort(1,1:burst_limit) == x),1:numel(electrode));


f1 = figure('Position',[200 200 800 400]);
tiledlayout(2,3)
nexttile(1,[1 2])
hold on
for ii = 1 : numel(electrode)
    if ismember(ii,idx_StimC)
        scatter(bursts(1:burst_limit),data(ii,1:burst_limit),25,Cmap(ii-(ii>3)*3,:),'filled')
    else
        scatter(bursts(1:burst_limit),data(ii,1:burst_limit),'SizeData',25,'MarkerFaceColor','k','MarkerEdgeColor',...
                'k','MarkerFaceAlpha',.4)
    end
end
ylabel('ERNA amplitude [\muV]')
legend(electrode)


title(sprintf('LH: DBS sel: %s [1^{th} rank: %1.2f %%]',electrode_ref,sum(ranking_prop(idx_StimC))*100))

nexttile(4,[1 2])
stairs(bursts(1:burst_limit),idx_sort(1,1:burst_limit),'linewidth',1.5,'color','K')
set(gca,'ydir','reverse')
ylim([0 numel(electrode)+1])
box off
yticks(1:numel(electrode))
xlabel('Burst [id]')
yticklabels(electrode)
xlim([1 burst_limit])

nexttile(6,[1 1])
barh(1:numel(electrode),ranking_prop*100,'FaceColor',[.8 .8 .8])
set(gca,'ydir','reverse')
box off
xlabel('1^{th} ERNA ranking [%]')
yticks(1:numel(electrode))
yticklabels(electrode)
xline(100/numel(electrode),'--k')


if numel(nargout) == 1
    varargout{1} = f1;
end

