"""
Python version of process_ota_captures.m
raw RTL .dat (1 MHz, float32 I/Q interleaved) -> normalized 1024-sample frames @ 200 kHz
Output: one .npz with train/val/test arrays ready for Keras.

"""

import os
import glob 
import numpy as np 


print('Processing OTA captures...  ')