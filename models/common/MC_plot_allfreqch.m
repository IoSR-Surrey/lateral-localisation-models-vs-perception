function [] = MC_plot_allfreqch(timefreqsignals,cfs,varargin)


%% Check input options
definput.keyvals.analysis_freqs = [];
definput.keyvals.color = [];
definput.keyvals.normalise_lims = [];


[flags, kv]  = ltfatarghelper({}, ...
                             definput, varargin);


if (~isempty(kv.analysis_freqs))
    for ff = 1:length(kv.analysis_freqs)
        idx(ff) = find(cfs>kv.analysis_freqs(ff),1,'first');
    end
    
    cfs = cfs(idx);
    timefreqsignals = timefreqsignals(:,idx);
end

if (isempty(kv.color))
    kv.color = [0 0 0];
end

plotGap = max(timefreqsignals(:));
%plotGap = 2*max(timefreqsignals(:));

%figure(132);
%figure;
for i = 1:length(cfs)
    %plot(timefreqsignals(:,i) + (length(cfs)+1-i)*plotGap); hold on;
    if isempty(kv.normalise_lims)
        plot(timefreqsignals(:,i)./(max(abs(timefreqsignals(:,i)))+eps^2) + 2*i-1,'Color',kv.color,'LineWidth',2); hold on;
    else
        plot((timefreqsignals(:,i)-kv.normalise_lims(2))./(kv.normalise_lims(2) - kv.normalise_lims(1)) + 1+ 2*i-1,'Color',kv.color,'LineWidth',2); hold on;
    end
end
yticks([1:2:2*i])
%yticklabels(round([cfs(end:-1:1)]/1000,1))
yticklabels(round([cfs(1:end)]/1000,1))

ylabel('Characteristic frequency (kHz)')
xlabel('Time (samples)')
%title("Gammatone Filterbank Output")