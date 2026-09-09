function [monaural_out] = MC_monauralProcessing(peripheral_out,varargin)

% Input parameters
    % peripheral_out: 

% Output parameter
    % monaural_out:
    

    %% Check input options
    definput.keyvals.mon_method = [];
    
    [flags, kv]  = ltfatarghelper({}, ...
                                 definput, varargin);
    if isempty(kv.mon_method)
        mon_method = 'none';
    end

    monaural_out = peripheral_out;

    switch kv.mon_method
        case 'adaptLoop'
            % minlvls_paulick = 1e-6*[114.6010 112.6388 110.5593 115.6323 122.8003 128.3473 129.4167 130.5499 134.9603 140.6641... 
            %     146.7089 147.9811 148.9594 149.9962 142.9728 133.7308 123.9364 116.7957 110.2674 103.3490...
            %     96.4875 89.5786 82.2569 74.4976 66.1913 57.3802 48.0427 42.4791 40.9715 39.3738...
            %     37.6163 31.9073 25.8572 19.4456 14.2276 11.9080 9.4499 6.8449 5.6897 6.3316... 
            %     7.0118 7.7326 7.1594 6.2346 5.2545 4.2159 3.5157 2.7790 1.9983 1.1709];
            % minlvls_f = erbspace(250,8000,50);
            % minlvls = interp1(minlvls_f,minlvls_paulick,peripheral_out.cfs);
            % if isnan(minlvls(1))
            %     val0 = find(minlvls>0,1,'first');
            %     minlvls(isnan(minlvls)) = minlvls(val0);
            % end

            minlvls = mean(squeeze(rms(peripheral_out.gaussian_noise)));

            monaural_out.bin_input(:,1,:) = adaptloop(squeeze(peripheral_out.ntout(:,1,:)),peripheral_out.fs,100,minlvls,[0.005 0.05 0.129 0.253 0.500]); % Values from Jensen, from Paulick2024
            monaural_out.bin_input(:,2,:) = adaptloop(squeeze(peripheral_out.ntout(:,2,:)),peripheral_out.fs,100,minlvls,[0.005 0.05 0.129 0.253 0.500]); % Values from Jensen, from Paulick2024
        
        case 'gaussianNoise'
            
            monaural_out.bin_input = peripheral_out.ntout + peripheral_out.gaussian_noise;

        case 'none'
            monaural_out.bin_input = peripheral_out.ntout;
    end
end