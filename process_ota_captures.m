clc; clear; close all

capDir = "iq_captures";                                 % .folder contain .dat files
dataDir = fullfile(tempdir, "ModClassDataFiles_OTA");   % keep separate from synthetic

files = dir(fullfile(capDir, "*.dat"));

modulationTypes = categorical(sort(["BPSK", "QPSK", "8PSK", "16QAM", "GFSK", "Noise"])); 
sps = 8; spf = 1024; fs = 200e3; 

fsRx = 1e6;                                     % RTL sample rate
decFac = fsRx / fs;                             % 5
fshift = 200e3;                                 % Tx put the signal at +200 kHz 
transDelay = 5;                                 % Sample drop at the start
skipSec = 0.1;                                  % drop RTL start-up samples 
fileNameRoot = "frame"; 

% start fresh each run so old frames from a previous run don't mix in
if exist(dataDir, 'dir')
    rmdir(dataDir, 's')                          % 's' = delete folder and everything inside
end  

mkdir(dataDir);

classNames = lower(string(modulationTypes));   
counts = zeros(1, numel(modulationTypes));

% List every .dat file 
files = dir(fullfile(capDir, "*.dat"));
for f = files'                                 % files' is 1x6 -> 6 columns (for loops; loop over columns)
    tok = lower(extractBefore(string(f.name), "_"));
    idx = find(classNames == tok);             % Obtain idx for each class [1,2,3,4,5,6]

    % Check if the idx exist; did we provide modulationTypes
    if isempty(idx)
        fprintf("skip %s (unknown class '%s')\n", f.name, tok)
        continue
    end

    labels = modulationTypes(idx);
    isNoise = (labels == "Noise");

    % fname = fullfile(f.folder,f.name) -> 'C:\Users\Public\Documents\research\iq_captures\16qam_01.dat
    x = readComplexDat(fullfile(f.folder, f.name));
    pk = max(abs(x)); 
    fprintf("%-16s %5.1f s  peak %.2f", f.name, numel(x)/fsRx, pk)
    
    % Check if the power received clip above what RTL can received
    if pk > 0.95
        fprintf("   <-- RTL CLIPPING: raise tx_atten / lower tx_amp");
    end 
    fprintf("\n")
    
    x = x(round(skipSec*fsRx) + 1: end);       % drop first 0.1 s (100k samples): RTL start-up transients
    

    % -- Frequency correction: nominal +200 kHz plus the measured
    % Pluto/RTL oscillator offset (signal classes only) -- 
    fOff = fshift; 
    if ~isNoise
        fOff = estimateCenter(x, fsRx, fshift); 
        fprintf("    signal found at %+.1f kHz (offset %+.2f kHz)\n", fOff/1e3, (fOff - fshift)/1e3);

        if abs(fOff - fshift) > 30e3
            warning("Large offset - check fc on both nodes | that the Tx was on")
        end 
    end 

    n = (0:numel(x)-1).';
    x = x .* exp(-1j*2*pi*fOff / fsRx*n);

    % Opposite to make_tx_wavforms
    % 1 MHz -> 200 kHz (the low-pass also removes the DC spikes, which are
    % now at -200 kHz)
    x = resample(x, 1, decFac); 


    % similar structure as test.m (i.e., lines 102-154)
    chunk = 2*spf;                            % 2048
    for k = 1:floor(numel(x)/chunk)           % 1:4833 
        rxSamples = x((k-1)*chunk + (1:chunk));
        frame = helperModClassFrameGenerator(rxSamples, spf, spf, transDelay, sps); 
        snr = NaN; 
        counts(idx) = counts(idx) + 1;
        fileName = fullfile(dataDir, sprintf("%s%s%05d", fileNameRoot, string(labels), counts(idx)));
        save(fileName, "frame", "labels", "snr")
    end 

end 


disp("Frames per class:")
disp(array2table(counts, VariableNames=cellstr(string(modulationTypes))))
disp("Saved to " + dataDir)


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% -- Helper Functions -- %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function x = readComplexDat(fname)
    fid = fopen(fname, "r"); 
    raw = fread(fid, Inf, 'float32');          % raw = [I1; Q1; I2; Q2; I3; Q3]
    fclose(fid); 
    x = complex(raw(1:2:end), raw(2:2:end));   % raw(1:2:end) -> I1, I2, I3
                                               % raw(2:2:end) -> Q1, Q2, Q3
                                               % x = I1 +- Q1 (i.e.,
                                               % complex)
end


function fc = estimateCenter(x, fs, fNorm)
    % Power-weighted spectral centroid within +/-60 kHz of the nominal spot
    nfft = 8192;                               % resolution = fs / nfft 
    
    % Power spectrum via Welch's method (average of many FFTs -> smooth spectrum)
    %   x(1:min(end,2e6)) : first 2 s of data (or whole file if shorter)
    %   hann(nfft)        : window tapers segment edges -> less spectral leakage
    %   nfft/2            : 50% overlap -> no wasted data, ~487 segments averaged
    %   nfft = 8192       : FFT size -> resolution fs/nfft ~ 122 Hz per bin
    %   fs                : sample rate, so f is in Hz
    %   'centered'        : f runs -fs/2..+fs/2 (-500..+500 kHz), DC at 0
    % Outputs: P = power per Hz at each freq, f = frequency vector (Hz)
    [P, f] = pwelch(x(1:min(end, 2e6)), hann(nfft), nfft/2, nfft, fs, 'centered'); 
    band = abs(f - fNorm) < 60e3; 
    Pb = P(band) - median(P);                  % Substract noise floor
    Pb(Pb < 0) = 0;
    fc = sum(f(band) .* Pb) / sum(Pb); 
end 