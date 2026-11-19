"""
Train a CNN on the OTA frames from process_captures.py, built layer by layer
with Sequential (same layers as MATLAB's helperModClassCNN).
"""
import os 
import logging 
import warnings 
import numpy as np
import matplotlib.pyplot as plt

################################################################################
# [OPTIONAL] Disable TensorFlow logging messages (i.e., INFO, WARNING, ERROR)

# -- Supress C++ backend logs (0=all, 1=no INFO, 2=no WARNING, 3=no ERROR) --
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '2'
os.environ['TF_ENABLE_ONEDNN_OPTS'] = '0'       

# -- Supress TensorFlow logging messages (i.e., INFO, WARNING, ERROR) --
import tensorflow as tf
tf.get_logger().setLevel('ERROR')

# -- Supress standard Python logging messages (i.e., FutureWarning or DeprecationWarning) -- 
warnings.filterwarnings('ignore')
#################################################################################

from tensorflow import keras
from tensorflow.keras import Sequential, regularizers, callbacks    
from tensorflow.keras.layers import (Input, Conv1D, BatchNormalization, ReLU, MaxPooling1D, GlobalMaxPooling1D, Dropout, Dense)
from sklearn.metrics import ConfusionMatrixDisplay



# -- Load data --
d = np.load("ota_frames.npz")
classes = list(d["classes"])
x_train, y_train = d["x_train"], d["y_train"]
x_val, y_val  = d["x_val"], d["y_val"]
x_test, y_test = d["x_test"], d["y_test"]

print(f"Classes: {classes}", f"x_train_shape: {x_train.shape}")



# -- Hyperparameters --
k = len(classes)
initial_lr = 3e-4
maxEpochs = 20
miniBatchSize = 256 
sps = 8                                          #samples per symbol (sps) = 8, each filter see sees one full symbol at a time (i.e., same as MATLAB's helperModClassCNN)
l2 = regularizers.l2(5e-5)                      #L2 regularization factor (i.e., a small penalty on large weights to reduce overfitting, MATLAB default with a factor of 1/2)

# -- Build model (i.e., layer by layer) --
model = Sequential()
model.add(Input(shape=x_train[0].shape))         # x_train[0].shape = (1024, 2)
model.add(Conv1D(filters=16, kernel_size= sps, padding="same", kernel_regularizer=l2))
model.add(BatchNormalization(momentum=0.9))
model.add(ReLU())
model.add(MaxPooling1D(pool_size=2, strides=2))

model.add(Conv1D(filters=32, kernel_size=sps, padding="same", kernel_regularizer=l2))
model.add(BatchNormalization(momentum=0.9))
model.add(ReLU())
model.add(MaxPooling1D(pool_size=2, strides=2))

model.add(Conv1D(filters=48, kernel_size=sps, padding="same", kernel_regularizer=l2))
model.add(BatchNormalization(momentum=0.9))
model.add(ReLU())
model.add(MaxPooling1D(pool_size=2, strides=2))

model.add(Conv1D(filters=64, kernel_size=sps, padding="same", kernel_regularizer=l2))
model.add(BatchNormalization(momentum=0.9))
model.add(ReLU())
model.add(MaxPooling1D(pool_size=2, strides=2))

model.add(Conv1D(filters=32, kernel_size=sps, padding="same", kernel_regularizer=l2))
model.add(BatchNormalization(momentum=0.9))
model.add(ReLU())


model.add(GlobalMaxPooling1D())
model.add(Dropout(0.2))
model.add(Dense(k, activation="softmax"))

model.summary()

# -- Call back -- 
cb = [
    callbacks.EarlyStopping(
        monitor='val_loss',
        patience=5,
        restore_best_weights=True
    ),
    callbacks.ModelCheckpoint(
        "modClassNet_ota.keras",
        monitor='val_loss',
        save_best_only=True,
        verbose=1 
    )

]


# -- Compile and fit (Make sure to used the GPU for this) --
model.compile(optimizer=keras.optimizers.Adam(initial_lr), 
              loss='sparse_categorical_crossentropy', 
              metrics=['accuracy'])

r = model.fit(x_train, y_train, 
              validation_data=(x_val, y_val), 
              epochs=maxEpochs, 
              batch_size=miniBatchSize, 
              verbose=1, 
              shuffle=True, 
              callbacks=cb)


# -- Plot loss per iteration -- 
plt.plot(r.history['loss'], label='loss')
plt.plot(r.history['val_loss'], label='val_loss')
plt.xlabel('epochs')
plt.ylabel('loss')
plt.legend()
plt.savefig('loss.png')
plt.show()


# -- Plot accuracy per iteration --
plt.plot(r.history['accuracy'], label='accuracy')
plt.plot(r.history['val_accuracy'], label='val_accuracy')
plt.xlabel('epochs')
plt.ylabel('accuracy')
plt.legend()
plt.savefig('accuracy.png')
plt.show()

