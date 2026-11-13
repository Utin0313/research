"""
Python version of process_ota_captures.m
raw RTL .dat (1 MHz, float32 I/Q interleaved) -> normalized 1024-sample frames @ 200 kHz
Output: one .npz with train/val/test arrays ready for Keras.
"""

import os
import glob
import numpy as np
from scipy.signal import welch, resample_poly


# -- Settings --
cap_dir = 'iq_captures'
out_file = 'ota_frames.npz'

classes = ['BPSK', 'QPSK', '8PSK', '16QAM', 'GFSK', 'NOISE']
sps = 8
spf = 1024
fs = 200e3
fshift = 200e3
fsRx = 1e6
deFac = int(fsRx / fs)   # decimation factor
transDelay = 5
skipSec = 0.1

rng = np.random.default_rng(12)


# -- Helper functions --
def readIQfile(filePath):
    return np.fromfile(filePath, dtype=np.complex64)


def estimateCenter(x, fs, fNorm, nfft=8192, halfband=60e3):
    f, P = welch(x[:int(2e6)],
                 fs=fs,
                 window='hann',
                 nperseg=nfft,
                 noverlap=nfft // 2,
                 nfft=nfft,
                 detrend=False,
                 return_onesided=False)

    band = np.abs(f - fNorm) < halfband
    Pb = np.clip(P[band] - np.mean(P[band]), 0, None)
    if Pb.sum() == 0:
        return np.nan
    return np.sum(Pb * f[band]) / np.sum(Pb)


def frame_generator(x, window_len, step, offset, sps):
    start = offset + rng.integers(0, sps + 1)    # random start, 0..sps samples
    frames = []
    while start + window_len <= len(x):
        w = x[start:start + window_len]
        w = w / np.sqrt(np.mean(np.abs(w) ** 2))  # normalize to unit average power
        frames.append(w)
        start += step
    return frames                                 # list of (window_len,) arrays


# -- Main --
frames = {}                                      # frames = {'BPSK': [], 'QPSK': [], ...}
for m in classes:
    frames[m] = []

n0 = int(round(skipSec * fsRx))

for fname in sorted(glob.glob(os.path.join(cap_dir, '*.dat'))):
    label = os.path.basename(fname).split('_')[1].upper()
    if label not in classes:
        continue

    x = readIQfile(fname)
    pk = max(np.max(np.abs(x.real)), np.max(np.abs(x.imag)))
    if pk > 0.95:
        print(f'Warning: {fname} has peak {pk:.3f} > 0.95, skipping')
        continue

    x = x[n0:]                                    # skip first 0.1 s

    if label == 'NOISE':                          # no signal -> use nominal shift (like MATLAB)
        fOff = fshift
    else:
        fOff = estimateCenter(x, fsRx, fshift)
    if np.isnan(fOff):
        print(f'    {fname}: no signal found, using nominal {fshift/1e3:.1f} kHz')
        fOff = fshift
    else:
        print(f'    {fname}: signal at {fOff/1e3:+.1f} kHz (offset {(fOff - fshift)/1e3:+.2f} kHz)')

    x = x * np.exp(-1j * 2 * np.pi * fOff / fsRx * np.arange(len(x)))  # shift to baseband
    x = resample_poly(x, 1, deFac)                                      # decimate to 200 kHz

    chunk = 2 * spf                                                     # 2 frames at a time
    for k in range(1, len(x) // chunk + 1):
        rxSample = x[(k - 1) * chunk:k * chunk]
        frames[label].extend(frame_generator(rxSample, window_len=spf, step=spf,
                                             offset=transDelay, sps=sps))

counts = [len(frames[m]) for m in classes]
print('Frames per class:', dict(zip(classes, counts)))
if min(counts) == 0:
    raise RuntimeError('A class has 0 frames - check file names and cap_dir')


# -- Split each class into train/val/test sets --
x_train, y_train, x_val, y_val, x_test, y_test = [], [], [], [], [], []
for k, m in enumerate(classes):
    f = np.array(frames[m])                                     # (N, 1024) complex
    f = np.stack([f.real, f.imag], axis=-1).astype(np.float32)  # (N, 1024, 2): I, Q
    a, b = int(0.8 * len(f)), int(0.9 * len(f))
    x_train.append(f[:a]);  y_train.append(np.full(a, k))
    x_val.append(f[a:b]);   y_val.append(np.full(b - a, k))
    x_test.append(f[b:]);   y_test.append(np.full(len(f) - b, k))

np.savez(out_file, classes=classes,
         x_train=np.concatenate(x_train), y_train=np.concatenate(y_train),
         x_val=np.concatenate(x_val),     y_val=np.concatenate(y_val),
         x_test=np.concatenate(x_test),   y_test=np.concatenate(y_test))

print('Saved to', out_file)