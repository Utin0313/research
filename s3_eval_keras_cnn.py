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

from sklearn.metrics import ConfusionMatrixDisplay


# -- Load data --
d = np.load("ota_frames.npz")
classes = list(d["classes"])
x_train, y_train = d["x_train"], d["y_train"]
x_val, y_val  = d["x_val"], d["y_val"]
x_test, y_test = d["x_test"], d["y_test"]

# -- Load the model --
model = tf.keras.models.load_model("modClassNet_ota.keras")


# -- Predict on the test data --
y_prob = model.predict(x_test)        # (N, 6) probabilities
y_pred = y_prob.argmax(axis=1)        # (N, ) predicted per class

disp = ConfusionMatrixDisplay.from_predictions(
    y_test, 
    y_pred,
    display_labels=classes,
    normalize='true', 
    values_format='.2f'
)

plt.show()