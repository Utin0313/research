clc; clear; close all;

%% ============================================================
%  Modulation classification - data generation
%  6 classes (5 modulations + Noise), random SNR per frame
%% ============================================================

% -- 6 classes: 5 modulations + "Noise" (nothing transmitted) --
modulationTypes = categorical(sort(["BPSK", "QPSK", "8PSK", "16QAM", "GFSK", "Noise"]));

% -- Number of frames per class (80% train, 10% val, 10% test) --
trainNow = true;
if trainNow == true
    numFramesPerModType = 10000;    % 6 x 10000 = 60000 frames total
else
    numFramesPerModType = 200;      % quick test run
end

percentTrainingSamples   = 80;
percentValidationSamples = 10;
percentTestSamples       = 10;

sps = 8;             % samples per symbol
spf = 1024;          % samples per frame
fs  = 200e3;         % sampling rate
fc  = [915e6 100e6]; % center frequency (digital, analog)

% -- SNR values to pick from (dB). One is chosen at random for each frame --
snrValues = -10:2:30;   % -10, -8, ..., 28, 30 dB


%% ------------------------------------------------------------
%  Channel: multipath fading + clock offset
%  Noise is NOT added here (SNR = 100 dB, basically off).
%  We add the noise ourselves later so we control the SNR.
%% ------------------------------------------------------------
channel = helperModClassTestChannel( ...
    'SampleRate', fs, ...
    'SNR', 100, ...                          % effectively no noise from the channel
    'PathDelays', [0 1.8 3.4] / fs, ...      % 3 echoes at different delays
    'AveragePathGains', [0 -2 -10], ...      % strength of each echo (dB)
    'KFactor', 4, ...                        % Rician: direct path vs scattered paths
    'MaximumDopplerShift', 4, ...            % movement-induced frequency drift (Hz)
    'MaximumClockOffset', 5, ...             % TX/RX oscillator mismatch (ppm)
    'CenterFrequency', fc(1));

chInfo = info(channel)


%% ------------------------------------------------------------
%  Where to save the frames
%% ------------------------------------------------------------
rng(12)              % fixed seed -> same frames every time you run this
tic
numModulationTypes = length(modulationTypes);
transDelay = 50;     % samples to drop at the start (filter/channel start-up)

pool = getPoolSafe();
if ~isa(pool, "parallel.ClusterPool")
    dataDir = fullfile(tempdir, "ModClassDataFiles_varSNR");   % new folder, don't mix with old 30 dB frames
else
    dataDir = uigetdir("", "Select network location to save data files");
end
disp("Data file directory is " + dataDir)

fileNameRoot = "frame";

% -- Skip generation if all files already exist --
dataFileExist = false;
if exist(dataDir, 'dir')
    files = dir(fullfile(dataDir, sprintf("%s*", fileNameRoot)));
    if length(files) == numModulationTypes * numFramesPerModType
        dataFileExist = true;
    end
end


%% ------------------------------------------------------------
%  Generate the frames
%% ------------------------------------------------------------
if ~dataFileExist
    disp("Generating data and saving in data files...")
    [success, msg, msgID] = mkdir(dataDir);
    if ~success
        error(msgID, msg)
    end

    for i = 1:numModulationTypes
        elapsedTime = seconds(toc);
        elapsedTime.Format = 'hh:mm:ss';
        fprintf('%s - Generating %s frames\n', elapsedTime, modulationTypes(i))

        labels  = modulationTypes(i);
        isNoise = (modulationTypes(i) == "Noise");

        % -- Data source + modulator only exist for real modulations --
        if ~isNoise
            dataSrc   = helperModClassGetSource(modulationTypes(i), sps, 2*spf, fs);
            modulator = helperModClassGetModulator(modulationTypes(i), sps, fs);
        end

        for p = 1:numFramesPerModType

            if isNoise
                % ===================== NOISE CLASS =====================
                % Nobody is transmitting -> receiver only picks up noise.
                % randn + 1j*randn has power 2 (1 from I, 1 from Q),
                % dividing by sqrt(2) makes the power 1.
                % 2*spf samples = same length as the modulated signals.
                rxSamples = (randn(2*spf,1) + 1j*randn(2*spf,1)) / sqrt(2);
                snr = NaN;      % no signal -> SNR doesn't exist

            else
                % ==================== SIGNAL CLASSES ===================
                x = dataSrc();              % random symbols
                y = modulator(x);           % modulate (BPSK, QPSK, ...)
                rxSamples = channel(y);     % fading + clock offset (no noise yet)

                % -- 1) Pick this frame's SNR at random --
                snr = snrValues(randi(numel(snrValues)));

                % -- 2) MEASURE the signal power (unknown, fading changes it) --
                %       power = average of |sample|^2
                %       "omitnan": the channel's clock-offset resampling can leave
                %       NaN in the last sample(s); skip them so Psignal isn't NaN.
                %       (Those tail samples are cut off by the frame generator anyway.)
                Psignal = mean(abs(rxSamples).^2, "omitnan");

                % -- 3) Solve SNR(dB) = 10*log10(Psignal/Pnoise) for Pnoise --
                Pnoise = Psignal / 10^(snr/10);

                % -- 4) BUILD noise with power Pnoise --
                %       size(rxSamples) only gives the shape -> one noise value per sample
                %       raw complex noise (randn + 1j*randn) has power 2
                %       scale AMPLITUDE by sqrt(Pnoise/2)
                %       -> power = 2 * (sqrt(Pnoise/2))^2 = 2 * Pnoise/2 = Pnoise
                noise = sqrt(Pnoise/2) * (randn(size(rxSamples)) + 1j*randn(size(rxSamples)));

                % -- (optional check, uncomment to verify, prints a LOT) --
                % fprintf("target Pnoise = %.4f | actual = %.4f\n", Pnoise, mean(abs(noise).^2))

                % -- 5) ADD the noise to the signal --
                rxSamples = rxSamples + noise;
            end

            % -- Drop start-up transients, cut to 1024 samples, normalize to power 1 --
            %    (normalizing erases absolute levels -> only the SNR ratio matters)
            frame = helperModClassFrameGenerator(rxSamples, spf, spf, transDelay, sps);

            % -- Save frame, its label, and its SNR (for accuracy-vs-SNR later) --
            fileName = fullfile(dataDir, ...
                sprintf("%s%s%05d", fileNameRoot, modulationTypes(i), p));
            save(fileName, "frame", "labels", "snr")
        end
    end
else
    disp("Data files exist. Skip data generation.")
end