"""
Train a CNN on the OTA frames from process_captures.py, built layer by layer
with Sequential (same layers as MATLAB's helperModClassCNN).
"""
import numpy as np
import matplotlib.pyplot as plt
from tensorflow import keras
from tensorflow.keras import Sequential, regularizers
from tensorflow.keras.layers import (Input, Conv1D, BatchNormalization, ReLU,
                                     MaxPooling1D, GlobalAveragePooling1D,
                                     Dropout, Dense)
from sklearn.metrics import ConfusionMatrixDisplay

# -- Load data --
d = np.load("ota_frames.npz")
classes = list(d["classes"])
x_train, y_train = d["x_train"], d["y_train"]
x_val, y_val  = d["x_val"], d["y_val"]
x_test, y_test = d["x_test"], d["y_test"]
k = len(classes)




