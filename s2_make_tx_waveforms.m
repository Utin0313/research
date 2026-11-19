clc; clear; close all

% Defined 
modulationTypes = ["BPSK", "QPSK", "8PSK", "16QAM", "GFSK"];

sps = 8; 
fs = 200e3;

fsTx = 1e6;      % Pluto/RTL rate. RTL can't run at 200e3 Hz, and Pluto min is ~521 kHz.
upFac = fsTx/fs; % 1e6/2e5 = 5 (i.e., make 5 output samples for every input samples).

fshift = 200e3;  % Put the signal at fc + 200kHz, away from the Pluto LO 
                 % Leakage and the RTL DC Spike (both sit at fc) 

durSec = 5;      % Seconds of unique data before the File Source loops


outDir = "tx_waveforms"; 
if ~exist(outDir, 'dir'), mkdir(outDir); end 
rng(7)

N = durSec * fs;         % 1e6 baseband samples (multiple of sps)


for m = modulationTypes
    
    dataSrc = helperModClassGetSource(m, sps, N, fs);
    modulator = helperModClassGetModulator(m, sps, fs); 

    y = modulator(dataSrc()); 

    % 200 kHz -> 1 MHz (i.e., produced 5 times as many samples from orgin 200e3 kHz)
    yTx = resample(y, upFac, 1);


    % Shift up by fShift (e.g., 200e3 kHz) 
    % numel(yTx)*fShift is an interger (e.g., 0, 1, 2, ..., 4999999) so the
    % phase lines up when the file loop. 
    n = (0:numel(yTx) - 1).';
    yTx = yTx .* exp(1j*2*pi*fshift / fsTx*n); 

    % Peak at 0.9 -> no DAC clipping; set the actual level with
    % tx_amp/tx_atten
    yTx = 0.9 * yTx / max(abs(yTx)); 

    fname = fullfile(outDir, lower(m) + "_tx.dat"); 
    writeComplexDat(fname, yTx); 
    fprintf("%-6s -> %s (%.1f s, %.1f MB)\n", m, fname, numel(yTx)/fsTx, numel(yTx)* 8/1e6); 

end 

% -- helper function --
function writeComplexDat(fname, x)
    fid = fopen(fname, 'w');
    fwrite(fid, [real(x(:)).'; ...
                 imag(x(:)).'], 'float32')   % I,Q,I,Q ... 
    fclose(fid); 
end 