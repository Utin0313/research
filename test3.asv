clc; clear; close all




s  = makeWaveform("QPSK", 8, 51200, 200e3);
PnTrue = 1e-3;
n  = sqrt(PnTrue/2)*(randn(size(s)) + 1j*randn(size(s)));   % noise riding on the signal
n2 = sqrt(PnTrue/2)*(randn(size(s)) + 1j*randn(size(s)));   % separate "TX off" capture
trueSNR = 10*log10(mean(abs(s).^2)/PnTrue)
estSNR  = estimateSNR(s + n, mean(abs(n2).^2))


for a = [1 0.1 0.03 0.01 0.005]
    trueSNR = 10*log10(mean(abs(a*s).^2)/PnTrue);
    estSNR  = estimateSNR(a*s + n, mean(abs(n2).^2));
    fprintf("true %6.1f dB   est %6.1f dB\n", trueSNR, estSNR)
end

function wave = makeWaveform(modType, sps, waveLen, fs)

    % Create dataSrc and modulator 
    dataSrc = helperModClassGetSource(modType, sps, waveLen, fs);
    modulator = helperModClassGetModulator(modType, sps, fs);
    wave = complex(modulator(dataSrc()));
    
    % Force complex (i.e., due to "BPSK" might introduce real comp.)
    % Scale so max(abs(wave)) == 0.7 (i.e., Pluto expects samples |x|<=1. 
    wave = 0.7 * wave(:) / max(abs(wave)); 

end 

function snr = estimateSNR(x, Pn)
    % pSN = |x|^2 
    Psn = mean(abs(x).^2);    % signal + noise

    % SNR in dB, guarded against Psn - Pn <= 0 (to ensure not below 0, 
    % since log10(0) = -inf, because Pn itself is a nosiy estimate)
    snr = 10 * log10(max(Psn - Pn, eps) / Pn);
    
end 


function x = captureFresh(rxRadio, nFlush)
    rx()

    for i = 1:nFlush
        rxRadio();
    end 
    x = rxRadio();
end


