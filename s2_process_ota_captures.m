clc; clear; close all

capDir  = "iq_captures";                               % .dat captures
dataDir = fullfile(tempdir, "ModClassDataFiles_OTA");  % separate from synthetic

modulationTypes = categorical(sort(["BPSK", "QPSK", "8PSK", "16QAM", "GFSK", "Noise"]));
sps = 8; spf = 1024; fs = 200e3;

fsRx       = 1e6;           % RTL sample rate
decFac     = fsRx / fs;     % 5
fshift     = 200e3;         % Tx at +200 kHz
transDelay = 5;             % samples dropped at start
skipSec    = 0.1;           % RTL start-up drop
chunk      = 2*spf;         % 2048
fileNameRoot = "frame";
snr = NaN;                  % OTA -> unknown

if isfolder(dataDir), rmdir(dataDir, 's'); end  % start fresh
mkdir(dataDir);

classNames = lower(string(modulationTypes));
counts = zeros(1, numel(modulationTypes));

for f = dir(fullfile(capDir, "rx160_*.dat"))'
    tok = extractBefore(lower(extractAfter(string(f.name), '_')), '_');  % rx160_<class>_xx.dat
    idx = find(classNames == tok);
    labels = modulationTypes(idx);

    x = readComplexDat(fullfile(f.folder, f.name));
    fprintf("%-16s %5.1f s  peak %.2f\n", f.name, numel(x)/fsRx, max(abs(x)))   % peak > 0.95 -> clipping
    x = x(round(skipSec*fsRx)+1:end);                 % drop RTL transients

    % Freq correction: nominal +200 kHz + measured LO offset (signals only)
    fOff = fshift;
    if labels ~= "Noise"
        fOff = estimateCenter(x, fsRx, fshift);
        fprintf("    signal at %+.1f kHz (offset %+.2f kHz)\n", fOff/1e3, (fOff-fshift)/1e3)
    end

    x = x .* exp(-1j*2*pi*fOff/fsRx*(0:numel(x)-1).');  % shift to baseband
    x = resample(x, 1, decFac);                          % 1 MHz -> 200 kHz (LPF also kills DC spike)

    for k = 1:floor(numel(x)/chunk)
        frame = helperModClassFrameGenerator(x((k-1)*chunk + (1:chunk)), spf, spf, transDelay, sps);
        counts(idx) = counts(idx) + 1;
        save(fullfile(dataDir, sprintf("%s%s%05d", fileNameRoot, string(labels), counts(idx))), ...
             "frame", "labels", "snr")
    end
end

disp("Frames per class:")
disp(array2table(counts, VariableNames=cellstr(string(modulationTypes))))
disp("Saved to " + dataDir)


%% -- Helper Functions --
function x = readComplexDat(fname)
    fid = fopen(fname, "r");
    raw = fread(fid, Inf, 'float32');          % [I1; Q1; I2; Q2; ...]
    fclose(fid);
    x = complex(raw(1:2:end), raw(2:2:end));   % I + jQ
end

function fc = estimateCenter(x, fs, fNom)
    % Power-weighted spectral centroid within +/-60 kHz of nominal
    nfft = 8192;                               % ~122 Hz/bin
    [P, f] = pwelch(x(1:min(end, 2e6)), hann(nfft), nfft/2, nfft, fs, 'centered');  % first 2 s, 50% overlap
    band = abs(f - fNom) < 60e3;
    Pb = max(P(band) - median(P), 0);          % remove noise floor
    fc = sum(f(band) .* Pb) / sum(Pb);
end