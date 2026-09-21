clc; clear; close all;

load trainedModulationClassificationNetwork
trainedNet 

modulationTypes = categorical(sort(["BPSK", "QPSK", "16QAM", "64QAM"])); 

