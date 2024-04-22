function [raw_reref] = bml_rereference_subctx_lfp(cfg, raw)

% BML_REREFERENCE_SUBCTX_LFP applies re-referencing scheme to subcortical
% lfp recordings. It appends new channels, bipolar referenced and common
% average referenced. This function assumes that macro_Lc exists, and the
% other channels are optional. 
% 
% Latane Bullock 18 July 2023; latanebullock@gmail.com
%
% Use as
%   [raw_reref,U] = bml_rereference_subctx_lfp(cfg, raw)
%
% cfg.label - Nx1 cellstr with labels. Defaults to raw.label
% cfg.group - Nx1 integer array identifying groups of electrodes
%   contacts of same group are re-referenced together
%   values <=0 and nans are not re-referenced. 
%   If not specified, groups are defined by string before underscore '_'
%   (i.e. ecog_*, micro_*, macro_*, audio_*, envaudio_*, etc)
% cfg.method - string, method to be implemented
%   'CAR', common average referencing (default)
%   'CARCF', common average referencing with cross fading
%   'CMR', common median referencing
%   'CTAR', common trimmed average referencing
%   'LAR', local average referencing
%   'VAR', variable average referencing
%   'bipolar', bipolar referencing
% cfg.percent - numeric, indicates percentage of labels in group used in
%   trimmed mean. Defaults to 50. 
% cfg.crossfading_width - scalar. Width in samples of the crossfading
%   region. Defaults to 100;
% cfg.refchan - either cellstr with label to use a reference for all
%   other channels, or table with label and reference column for custom
%   bipolar referencing montage
% cfg.refkeep - bool indicating if reference channels should be kept 
%
% raw - ft_datatype_raw to be re-referenced
% 
% Returns
% D_reref - ft_datatype_raw with re-referenced data
% U - double, unmixing matrix. ref = U * raw

assert(isstruct(raw),"invalid raw");
assert(all(ismember({'trial','time','label'},fieldnames(raw))),"invalid raw");


reref_scheme = {}; % order matters!
reref_scheme{end+1} = struct('method', 'append_CA', 'label', 'macro_L*');
reref_scheme{end+1} = struct('method', 'append_bipolar', 'label', 'macro_L*', 'refchan', 'macro_Lc');
reref_scheme{end+1} = struct('method', 'append_bipolar', 'label', 'macro_L*', 'refchan', 'macro_L_CA');

alldata = [raw.trial{:}]; 
if any(isnan(alldata(:)))
    warning('At least one trial contains NaNs. Rereferencing may not work as intended')
end

for ir = 1:length(reref_scheme)
    r = reref_scheme{ir};
    nchan = length(raw.label);
    switch r.method
        case 'append_CA'
            assert(strcmp(r.label(end), '*'));
            ichans = startsWith(raw.label, r.label(1:end-1)); % index of CAR channels
            if sum(ichans)==0, continue, end

            U = eye(nchan);
            U(end+1, :) = zeros(1, nchan); % add new channel
            U(end, ichans) = 1 / sum(ichans);
            for it = 1:length(raw.trial)
                raw.trial{it} = U * raw.trial{it};
            end
            raw.label{end+1, 1} = [r.label(1:end-1) '_CA'];
        case 'append_bipolar'
            if strcmp(r.label(end), '*')
                ichans = find(startsWith(raw.label, r.label(1:end-1)));
            else
                ichans = find(strcmp(raw.label, r.label(1:end-1)));
            end
            irefchan = find(strcmp(raw.label, r.refchan));
            ichans = setdiff(ichans, irefchan);
            if sum(ichans)==0, continue, end

            U = eye(nchan);
            for i = 1:length(ichans)
                tmp = zeros(1, nchan);
                tmp(ichans(i)) = 1; % anode
                tmp(irefchan) = -1; % cathode
                U = [U; tmp];
            end
            for it = 1:length(raw.trial)
                raw.trial{it} = U * raw.trial{it};
            end

            labels_new = raw.label(ichans); % append new labels
            for ilabel = 1:length(labels_new)
                labels_new{ilabel} = [labels_new{ilabel} '-' r.refchan];
            end
            raw.label = [raw.label; labels_new];
    end
end
% if there are channels that have been referenced multiple times, drop them
cfg = [];
cfg.channel = cellfun(@length, regexp(raw.label, 'macro')) <= 2;
cfg.channel = raw.label(cfg.channel);
raw = ft_selectdata(cfg, raw);

raw_reref = raw; 



end