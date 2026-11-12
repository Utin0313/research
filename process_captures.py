"""
Python version of process_ota_captures.m
raw RTL .dat (1 MHz, float32 I/Q interleaved) -> normalized 1024-sample frames @ 200 kHz
Output: one .npz with train/val/test arrays ready for Keras.

"""

import os
import glob
import numpy as np
import pandas as pd 
from scipy.signal import welch, resample_poly 
from scipy.signal.windows import hann 


# -- Setting -- 
cap_dir = 'iq_captures'
out_file = 'ota_frames.npz'

classes = ['BPSK', 'QPSK', '8PSK', '16QAM', '64QAM']
sps = 8
spf = 1024 
fs = 200e3
fshift = 200e3
fsRx = 1e6
deFac = int(fsRx/fs)  # decimation factor 
transDelay = 5
skipSec = 0.1
fileNameRoot = 'frame'


# -- Helper functions --
def readIQfile(filePath):
    return np.fromfile(filePath, dtype = np.complex64)

def estimateCenter(x, fs, fNorm, nfft = 8192, halfband = 60e3):             
    [f, P] = welch(x[:int(2e6)], 
                                fs = fs, 
                                window =  'hann',
                                nperseg = nfft,
                                noverlap = nfft//2,
                                nfft = nfft,
                                detrend = 'False',
                                return_onesided = False)

    band = np.abs(f -fNorm ) < halfband
    Pb = np.clip(P[band] - np.mean(P[band]), 0, None)
    if Pb.sum() == 0:
        return np.nan
    return np.sum(Pb * f[band]) / np.sum(Pb)

def frame_generator(x, window_len, step, offset, sps, rng=np.random.default_rng()):
    start = offset + rng.integers(0, sps + 1)   # random start, 0..sps samples
    frames = []
    while start + window_len < len(x):
        w = x[start : start + window_len]
        w = w / np.sqrt(np.mean(np.abs(w)**2))   # normalize to unit average power
        frames.append(w)
        start += step
    return np.array(frames)                      # shape (numFrames, window_len)

# -- Main -- 

n0 = int(round(skipSec * fsRx))

for fname in sorted(glob.glob(cap_dir + '/*.dat')):
    label = os.path.basename(fname).split('_')[1].lower()
    if label not in classes:
        continue
    idx = classes.index(label)

    x = readIQfile(fname)
    pk = max(np.max(np.abs(x.real)), np.max(np.abs(x.imag)))

    if pk > 0.95:
        print(f'Warning: {fname} has peak {pk:.3f} > 0.95, skipping')
        continue

    x = x[n0: n0 + spf]  # skip first 0.1 sec

    fOff = fshift
    Noise = False
    if not Noise:
        fOff = estimateCenter(x, fsRx, fshift)
        print(f"    signal at {fOff/1e3:+.1f} kHz (offset {(fOff - fshift)/1e3:+.2f} kHz)")

    x = x * np.exp(-1j * 2*np.pi * fOff/fsRx * np.arange(len(x)))  # shift to baseband
    x = resample_poly(x, 1, deFac)                                 # decimate to 200 kHz

    chunk = 2*spf                                                  # read 2 frames at a time
    for k in range(1, int(np.floor(len(x) / chunk))):
        rxSample = x[(k-1)*chunk : k*chunk]
        frame = frame_generator(rxSample, window_len=spf, step=spf, offset=transDelay, sps=sps)
        frames[label].append(frame)

    print("Frames per class:", dict(zip(classes, counts)))


# -- Split each class into train/val/test sets --
x_train, y_train, x_val, y_val, x_test, y_test = [], [], [], [], [], []
for 
    


