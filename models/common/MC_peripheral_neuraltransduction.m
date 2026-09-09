function [peripheral_out] = MC_peripheral_neuraltransduction(peripheral_out,varargin)

% Input parameters
    % peripheral_out: 
        % .gtfbout = output of the GTFB (nsamples x 2 x nfilters)
        % .cfs

% Output parameter
    % peripheral_out
        % .ntout

%Future varargin: 
    % LPF Freq for phase locking
    % Onset enhancement(e.g. "squared" in Faller & Merimaa 2004, or "onset enhancement" in Martin 1997)
    % 

    %% Check input options
    definput.keyvals.lpf_fc = [];
    definput.keyvals.lpf_order = [];
    definput.keyvals.apply_envelope = [];
    definput.keyvals.nt_compression_power = [];
    
    [flags, kv]  = ltfatarghelper({}, ...
                                 definput, varargin);
    
    if (isempty(kv.nt_compression_power))
        kv.nt_compression_power = 1;
    end

    if (isempty(kv.lpf_order))
        kv.lpf_order = 1;
    end

    if (isempty(kv.apply_envelope))
        kv.apply_envelope = "false";
    end
    
    % 1) half-wave rectification
    peripheral_out.ntout(:,1,:) = peripheral_out.gtfb(:,1,:).*(peripheral_out.gtfb(:,1,:)>0);
    peripheral_out.ntout(:,2,:) = peripheral_out.gtfb(:,2,:).*(peripheral_out.gtfb(:,2,:)>0);
    
    peripheral_out.ntout = peripheral_out.ntout.*abs(peripheral_out.ntout).^kv.nt_compression_power;

    % 2) LPF
    if (~isempty(kv.lpf_fc)) & (kv.lpf_fc ~= 0)  % if a lpf_fc has been specified
        % if kv.lpf_order == 1
        %     beta = exp(-kv.lpf_fc*2*pi/peripheral_out.fs);
        %     peripheral_out.ntout(:,1,:) = filter(1-beta,[1 -beta],peripheral_out.ntout(:,1,:));
        %     peripheral_out.ntout(:,2,:) = filter(1-beta,[1 -beta],peripheral_out.ntout(:,2,:));
        % 
        % else
            % From ihcenvelope (used in may, flag 'breebaart2001')
            % due to the successive application of the filter, the given 2000 Hz
            % correspond to a cut off-frequency of 770 Hz after the five iterations
            
            [b,a] = butter(kv.lpf_order,kv.lpf_fc*2/peripheral_out.fs);
            peripheral_out.ntout(:,1,:) = filter(b,a,peripheral_out.ntout(:,1,:));
            peripheral_out.ntout(:,2,:) = filter(b,a,peripheral_out.ntout(:,2,:));

            % [b, a] = butter(1, cutofffreq*2/fs);
            % for ii=1:kv.lpf_order
            %     peripheral_out.ntout(:,1,:) = filter(b,a, peripheral_out.ntout(:,1,:));
            %     peripheral_out.ntout(:,1,:) = filter(b,a, peripheral_out.ntout(:,1,:));
            % end
        % end
    end

    % 3) Envelope at high freq?

    %% Half wave rectification / Hilbert transform
    if kv.apply_envelope == "true"
        f_rectification_Hilbert = 1500;
        channels_neural_transduction = find(peripheral_out.cfs<f_rectification_Hilbert,1,'last');
        peripheral_out.ntout(:,1,channels_neural_transduction+1:end) = abs(hilbert(peripheral_out.gtfb(:,1,channels_neural_transduction+1:end)));
        peripheral_out.ntout(:,2,channels_neural_transduction+1:end) = abs(hilbert(peripheral_out.gtfb(:,2,channels_neural_transduction+1:end)));
    end


end