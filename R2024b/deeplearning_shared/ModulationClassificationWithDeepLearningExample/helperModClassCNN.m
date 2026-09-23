function modClassNet = helperModClassCNN(modulationTypes,sps,spf)
%helperModClassCNN Modulation classification CNN
%   CNN = helperModClassCNN(MODTYPES,SPS,SPF) creates a convolutional
%   neural network,CNN,for modulation classification. MODTYPES is the
%   modulation types the network can identify,SPS is the samples per
%   symbol,and SPF is the samples per frame.
%
%   The CNN consists of five convolution layers and one fully connected
%   layer. Each convolution layer except the last is followed by a batch
%   normalization layer, rectified linear unit (ReLU) activation layer, and
%   max pooling layer. In the last convolution layer, the max pooling layer
%   is replaced with a global average pooling layer. The output layer has
%   softmax activation.
%   
%   See also ModulationClassificationWithDeepLearningExample.

%   Copyright 2019-2023 MathWorks,Inc.

numModTypes = numel(modulationTypes);
netWidth = 1;
poolSize = 2;

modClassNet = [
  sequenceInputLayer(1,SplitComplexInputs=1,MinLength=spf,...
    Normalization="zscore",Name="Input Layer")

  convolution1dLayer(sps,16*netWidth,Padding="same",Name="CNN1")
  batchNormalizationLayer(Name="BN1")
  reluLayer(Name="ReLU1")
  maxPooling1dLayer(poolSize,Stride=poolSize,Name="MaxPool1")

  convolution1dLayer(sps,32*netWidth,Padding="same",Name="CNN2")
  batchNormalizationLayer(Name="BN2")
  reluLayer(Name="ReLU2")
  maxPooling1dLayer(poolSize,Stride=poolSize,Name="MaxPool2")

  convolution1dLayer(sps,48*netWidth,Padding="same",Name="CNN3")
  batchNormalizationLayer(Name="BN3")
  reluLayer(Name="ReLU3")
  maxPooling1dLayer(poolSize,Stride=poolSize,Name="MaxPool3")

  convolution1dLayer(sps,64*netWidth,Padding="same",Name="CNN4")
  batchNormalizationLayer(Name="BN4")
  reluLayer(Name="ReLU4")
  maxPooling1dLayer(poolSize,Stride=poolSize,Name="MaxPool4")

  convolution1dLayer(sps,32*netWidth,Padding="same",Name="CNN5")
  batchNormalizationLayer(Name="BN5")
  reluLayer(Name="ReLU5")
  globalAveragePooling1dLayer(Name="AP1")  

  fullyConnectedLayer(numModTypes,Name="FC1")
  softmaxLayer(Name="SoftMax")];