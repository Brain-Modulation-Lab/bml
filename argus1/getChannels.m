function Channels = getChannels(ChannelField, Signal)

% type SensingElectrodeConfigDef

% check if there is _0, _1, _2, _3
if contains(ChannelField,'FourElectrodes')
    tmp = strsplit(ChannelField,'_'); tmp = tmp{2};
    Channels = string([Signal,'-0',tmp]);    
    
elseif contains(ChannelField,'Case')
    tmp = strsplit(ChannelField,'.'); 
    tmp = tmp{2};
    Channels = string([Signal,'-C']);    
elseif contains(ChannelField,'_AND')
    %if ChannelField
    tmp = strrep(ChannelField,'_AND','');
    tmp = strsplit(tmp,'.'); tmp = tmp{end};

    tmp = strsplit(strrep(strrep(strrep(strrep(strrep(tmp,'ZERO','0'),'ONE','1'),'TWO','2'),'THREE','3'),'_',''),',');

    % modify channel labels
    pat = lettersPattern|digitsPattern;
    Channels = cell(1,numel(tmp));
    for ii = 1 : numel(tmp)
        ChannelsExt = extract(tmp{ii},pat);

        if numel(ChannelsExt) == 2 || numel(ChannelsExt) == 3
            if strcmpi(ChannelsExt{2},'RIGHT')
                Channels{ii} = [Signal,'-R',ChannelsExt{1}];
            elseif strcmpi(ChannelsExt{2},'LEFT')
                Channels{ii} = [Signal,'-L',ChannelsExt{1}];
            end
        elseif numel(ChannelsExt) == 1
            Channels{ii} = [Signal,'-',ChannelsExt{1}];
        end
    end

else % argus erna project (new brainsense mode)
    tmp = strsplit(ChannelField,'_'); 
    if isempty(tmp{end})
        tmp = tmp(1:(end-1));
    end
    Channels = string(strcat(tmp{:}));


end
% check consistency of channels
assert(numel(Channels) == 1 || numel(Channels) == 2, 'Warning: wrong montage settings on BrainSenseLFP modality')
