clc; clear; close all

load("modClassNet_trained_adam_varSNR.mat") 
otaDir = fullfile(tempdir, "ModClassDataFiles_OTA"); 

otaDS = signalDatastore(otaDir, SignalVariableNames=["frame", "labels"]);
rxFrames = readall(transform(otaDS, @helperModClassReadFrame));  % OTA received frames (test inputs)
rxLabels = readall(transform(otaDS, @helperModClassReadLabel));  % true labels of those same OTA frames
scores = predict(trainedNet, cat(3, rxFrames{:}));               % softmax probabilities, one column per class
rxPred = scores2label(scores, modulationTypes);                  % predicted label = class with highest score
disp("OTA accuracy (synthetic-trained model): " + mean(rxPred == rxLabels)*100 + "%")
 
figure
cm = confusionchart(rxLabels, rxPred);
cm.Title = 'CNN on OTA data';
cm.RowSummary = 'row-normalized';
 

% - ROC curve - (built in function)
rocObj = rocmetrics(rxLabels, scores, modulationTypes); 
rocObj.AUC
figure 
plot(rocObj)




