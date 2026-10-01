clc; clear; close all

% -- Directory -- 
modulationTypes = categorical(sort(["BPSK", "QPSK", "8PSK", "16QAM", "GFSK"]));
% dataDir = "C:\Users\trinh\AppData\Local\Temp\ModClassDataFiles";
dataDir = "C:\Users\Austin Trinh\AppData\Local\Temp\ModClassDataFiles"; 
fs = 200e3; 
sps = 8;
spf = 1024;


% -- Total frames 5 types x 10000 = 50000
percentTrainingSamples = 80;    % Train = 40000
percentValidationSamples = 10;  % Val = 1000
percentTestSamples = 10;        % Test = 1000

% -- Plot amplitude of real/img parts and spectrogram -- 
helperModClassPlotTimeDomain(dataDir, modulationTypes, fs)
helperModClassPlotSpectrogram(dataDir, modulationTypes, fs, sps)

frameDS = signalDatastore(dataDir, 'SignalVariableNames', ["frame", "labels"]); 
splitPercentages = [percentTrainingSamples, percentValidationSamples, percentTestSamples];
[trainDS, validDS, testDS] = helperModClassSplitData(frameDS, splitPercentages); 

% -- Import data into memory --
pctExists = parallelComputingLicenseExists(); 
trainFrames = transform(trainDS, @helperModClassReadFrame);
rxTrainFrames = readall(trainFrames, "UseParallel", pctExists);
validFrames = transform(validDS, @helperModClassReadFrame); 
rxValidFrames = readall(validFrames, "UseParallel", pctExists);

trainLabels = transform(trainDS, @helperModClassReadLabel); 
rxTrainLabels = readall(trainLabels, "UseParallel", pctExists);
validLabels = transform(validDS, @helperModClassReadLabel);
rxValidLabels = readall(validLabels, "UseParallel", pctExists); 


%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --   Train the CNN   -- %
%%%%%%%%%%%%%%%%%%%%%%%%%%%

modClassNet = helperModClassCNN(modulationTypes, sps, spf); 

maxEpochs = 20; 
miniBatchSize = 256; 
trainingPlots = "training-progress"; 
metrics = "Accuracy"; 
verbose = true; 
itersPerEpoch = floor(numel(rxTrainLabels) / miniBatchSize);  % floor(40000/256) ~ 156 


options = trainingOptions('adam', ...
    InitialLearnRate= 3e-1, ...
    MaxEpochs=maxEpochs, ...
    MiniBatchSize=miniBatchSize, ...
    Shuffle= 'every-epoch', ...
    Plots= trainingPlots, ...
    Verbose = verbose, ...
    ValidationData = {rxValidFrames, rxValidLabels}, ...
    ValidationFrequency = itersPerEpoch, ...
    ValidationPatience = 5, ...
    Metrics= metrics, ...
    LearnRateSchedule = 'piecewise', ...
    LearnRateDropPeriod = 6, ...
    LearnRateDropFactor = 0.75, ...
    OutputNetwork = 'best-validation-loss'); 

tic
fprintf('Training Network...\n')
trainedNet = trainnet(rxTrainFrames, rxTrainLabels, modClassNet, "crossentropy", options); 
fprintf('Training finished in %s\n', string(seconds(toc), 'hh:mm:ss'))

% -- Read the test frames into the memory -- 
testFrames = transform(testDS, @helperModClassReadFrame); 
rxTestFrames = readall(testFrames, "UseParallel", pctExists);

% -- Read the test labels into the memory -- 
testLabels = transform(testDS, @helperModClassReadLabel); 
rxTestLabels = readall(testLabels, "UseParallel", pctExists); 


% -- Confusion Matrix -- 
scores = predict(trainedNet, cat(3, rxTestFrames{:})); 
rxTestPred = scores2label(scores, modulationTypes); 
testAccuracy = mean(rxTestPred == rxTestLabels); 
disp("Test accuracy: " + testAccuracy*100 + "%")

% -- Save the model -- 
testFiles = testDS.Files; 
save("modClassNet_trained_adam.mat", "trainedNet", "modulationTypes", "testFiles", "sps", "spf", "fs")
disp("Model saved to modClassNet_trained.mat")