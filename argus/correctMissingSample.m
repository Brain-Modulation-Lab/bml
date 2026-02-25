function [isDataMissing, isReceived] = correctMissingSample(TimeStart, TicksInMses, GlobalPacketSizes, srate)


TicksInS = (TicksInMses - TicksInMses(1))/1000;
%TicksInS = (TicksInMses - TicksInMses(1))/1000 + TimeStart;
nPackets = numel(GlobalPacketSizes);
nTicks = numel(TicksInS);
if nPackets ~= nTicks
    warning('GlobalPacketSizes and TicksInMses have different lenght')
    maxPacketId = max([nPackets nTicks]);
    TicksInS = TicksInS(1 : nPackets);
end

% check if data is missing
isDataMissing = logical(TicksInS(end) >= sum(GlobalPacketSizes)/srate);


%Create time vector of all samples that should have been received theorically
time = TicksInS(1):1/srate:TicksInS(end)+(GlobalPacketSizes(end)-1)/srate;
time = round(time,3); %round to the ms


if isDataMissing
    %Create logical vector indicating which samples have been received
    isReceived = zeros(size(time, 2), 1);
    nPackets = numel(GlobalPacketSizes);
    for packetId = 1:nPackets
        timeTicksDistance = abs(time - TicksInS(packetId));
        [~, packetIdx] = min(timeTicksDistance);
        if isReceived(packetIdx) == 1
            packetIdx = packetIdx +1;
        end
        isReceived(packetIdx:packetIdx+GlobalPacketSizes(packetId)-1) = isReceived(packetIdx:packetIdx+GlobalPacketSizes(packetId)-1)+1;
    end
else
    isReceived = ones(size(time, 2), 1);
end




