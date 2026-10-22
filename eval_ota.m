clc; clear; close all

load("modClassNet_trained_adam_varSNR.mat") 
otaDir = fullfile(tempdir, "ModClassDataFiles_OTA"); 

otaDS = signalDatastore(otaDir, SignalVariableNames=["frame", "labels"]);
rxFrames = readall(transform(otaDS, @helperModClassReadFrame));
rxLabels = readall(transform(otaDS, @helperModClassReadLabel));
 
scores = predict(trainedNet, cat(3, rxFrames{:}));
rxPred = scores2label(scores, modulationTypes);
disp("OTA accuracy (synthetic-trained model): " + mean(rxPred == rxLabels)*100 + "%")
 
figure
cm = confusionchart(rxLabels, rxPred);
cm.Title = 'CNN on OTA data';
cm.RowSummary = 'row-normalized';
 







