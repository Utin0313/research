clc; clear; close all

% -- Load saved model -- 
load("modClassNet_trained_sgdm_varSNR.mat")
modulationTypes = categorical(sort(["BPSK", "QPSK", "8PSK", "16QAM", "GFSK", "Noise"]));
sps = 8;            % samples per symbol
spf = 1024;         % samples per frame
fs = 200e3;         % sampling rate 
fc = [915e6 100e6]; % Center fc (i.e., Digital & Analog)


% -- Rebuild the test set from the saved file list -- 
testDS = signalDatastore(testFiles, SignalVariableNames=["frame", "labels"]); 
rxTestFrames = readall(transform(testDS, @helperModClassReadFrame));
rxTestLabels = readall(transform(testDS, @helperModClassReadLabel)); 

% -- Predict all test frames -- 
scores = predict(trainedNet, cat(3, rxTestFrames{:})); 
rxTestPred = scores2label(scores, modulationTypes); 
testAccuracy = mean(rxTestPred == rxTestLabels); 
disp("Test accuracy: " + testAccuracy*100 + "%")

figure
cm = confusionchart(rxTestLabels, rxTestPred); 
cm.Title = 'Confusion Matrix (loaded model)';
cm.RowSummary = 'row-normalized'; 

% -- Plot 1 test frame per modulation: I/Q, first 16 symbols -- 
numSymbol = 16; 
t = (0:spf-1) / fs*1e3;
tZoom = numSymbol * sps / fs * 1e3;  % 16 symbols = 0.64 ms 

figure('Position', [100 100 1100 650])
tl = tiledlayout(ceil(numel(modulationTypes)/2), 2, TileSpacing="compact"); 
title(tl, "Test frames: first " + numSymbol + " symbols")

for i = 1:numel(modulationTypes)
    idx = find(rxTestLabels == modulationTypes(i), 1); 
    [I, Q] = getIQ(rxTestFrames{idx}); 

    nexttile
    plot(t, I, '-', LineWidth=1.2); hold on
    plot(t, Q, '-', LineWidth=1.2)
    xline((1:numSymbol-1) * sps / fs * 1e3, ':', Color=[0.6 0.6 0.6], HandleVisibility="off")
    hold off
    xlim([0 tZoom]); grid on
    xlabel("Time (ms)"); ylabel("Amplitude")
    legend(["I (real)", "Q (imag)"], Location="northeast")

    [conf, predIdx] = max(scores(idx, :));
    title(sprintf("True: %s | Pred: %s (%.1f%%)", ...
        string(rxTestLabels(idx)), string(modulationTypes(predIdx)), conf*100))
end 



% -- Helper function -- 
function [I, Q] = getIQ(frame)
    f = squeeze(frame); 

    % complex frames
    if ~isreal(f) 
        I = real(f(:)); 
        Q = imag(f(:));
    % real frames    
    else 
        if size (f, 2) ~= 2
            f = f.'; 
        end
        I = f(:, 1); 
        Q = f(:, 2); 
    end
end 








