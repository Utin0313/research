clc; clear; close all;

modulationTypes = categorical(sort(["BPSK", "QPSK", "8PSK", "16QAM", "GFSK"]));

 % -- Generate 10,000 frames for each modulation types (e.g., 80% train, 10% val, 10% test) --
 trainNow = true; 
 if trainNow == true
     numFramesPerModType = 10000; 
 else
     numFramesPerModType = 200;
 end 

percentTrainingSamples = 80; 
percentValidationSamples = 10;
percentTestSamples = 10; 

sps = 8;            % samples per symbol
spf = 1024;         % samples per frame
fs = 200e3;         % sampling rate 
fc = [915e6 100e6]; % Center fc (i.e., Digital & Analog)


% -- Simulate realworld scenario (i.e., channel impairment) --
% -- Include AWGN, Rician multipath, and clock offset -- 
channel = helperModClassTestChannel( ...
    'SampleRate', fs, ...
    'SNR', 30, ...
    'PathDelays', [0 1.8 3.4] / fs, ...           
    'AveragePathGains', [0 -2 -10], ...
    'KFactor', 4, ...
    'MaximumDopplerShift', 4, ...
    'MaximumClockOffset', 5, ...
    'CenterFrequency', fc(1))

chInfo = info(channel)


%%%%%%%%%%%%%%%%%%%%%%%%%%%
% -- Generate waveform -- %
%%%%%%%%%%%%%%%%%%%%%%%%%%%

% -- Syntax to check/store data -- 
rng(12)         % Set the rng to a known state to regenerate the same frames everytime the simulation is run
tic 
numModulationTypes = length(modulationTypes); 
transDelay = 50; 
pool = getPoolSafe();
if ~isa(pool, "parallel.ClusterPool")
    dataDir = fullfile(tempdir, "ModClassDataFiles"); 
else
    dataDir = uigetdir("", "Select network location to save data files"); 
end 
disp("Data file directory is " + dataDir)

fileNameRoot = "frame"; 

% -- Check if data files exist -- 
dataFileExist = false; 
if exist(dataDir, 'dir')
    files = dir(fullfile(dataDir, sprintf("%s*", fileNameRoot)));
    if length(files) == numModulationTypes * numFramesPerModType
        dataFileExist = true; 
    end 
end 


% -- If data not exist, generate it -- 
if ~dataFileExist
    disp("Generating data and saving in data files...")
    [success, msg, msgID] = mkdir(dataDir); 
    if ~success
        error(msgID, msg)
    end
    for i = 1:numModulationTypes
        elapsedTime = seconds(toc);
        elapsedTime.Format = 'hh:mm:ss'; 
        fprintf('%s - Generating %s frames\n', ...
            elapsedTime, modulationTypes(i))
        
        labels = modulationTypes(i); 
        numSymbols = (numFramesPerModType / sps); 
        dataSrc = helperModClassGetSource(modulationTypes(i), sps, 2*spf, fs); 
        modulator = helperModClassGetModulator(modulationTypes(i), sps, fs); 
        if contains(char(modulationTypes(i)), {'B-FM', 'DSB-AM', 'SSB-AM'})
            channel.CenterFrequency = 100e6;
        else 
            channel.CenterFrequency = 915e6; 
        end

        for p = 1:numFramesPerModType
            
            % Generate random data
            x = dataSrc();
            
            % Modulate
            y = modulator(x);
            
            % Pass through independent channels
            rxSamples = channel(y);
      
            % Remove transients from the beginning, trim to size, and normalize
            frame = helperModClassFrameGenerator(rxSamples, spf, spf, transDelay, sps);

            % Save data file
            fileName = fullfile(dataDir, ...
                sprintf("%s%s%03d", fileNameRoot, modulationTypes(i), p)); 
            save(fileName, "frame", "labels")
        end 
    end 
else 
    disp("Data files exist. Skip data generation.")
end 

