import serial
import time
import torch
import numpy as np
from torchvision import datasets, transforms
from PIL import Image

def process_image(img):
    bbox = img.getbbox()
    if bbox is None: return img.resize((28, 28), Image.Resampling.BILINEAR)
    cropped = img.crop(bbox)
    w, h = cropped.size
    if w > h: new_w, new_h = 20, max(1, int(20 * (h / w)))
    else: new_w, new_h = max(1, int(20 * (w / h))), 20
    resized = cropped.resize((new_w, new_h), Image.Resampling.BILINEAR)
    final_img = Image.new("L", (28, 28), "black")
    paste_x, paste_y = (28 - new_w) // 2, (28 - new_h) // 2
    final_img.paste(resized, (paste_x, paste_y))
    return final_img

print("Loading MNIST dataset to find a '2'...")
test_dataset = datasets.MNIST('./data', train=False, download=True)

# Find a random '2'
target_digit = 2
for i in range(np.random.randint(0, 100), len(test_dataset)):
    img, label = test_dataset[i]
    if label == target_digit:
        print(f"Found a '{target_digit}' at index {i}!")
        break

# Process exactly as host_gui does
img_centered = process_image(img)
pixel_array  = np.array(img_centered, dtype=np.float32) / 255.0

# Map to INT8 [-127, 127]
int8_array   = np.clip(np.round(pixel_array * 254.0 - 127.0), -127, 127).astype(np.int8)

# Convert to uint8 for raw byte transmission over serial
uint8_array  = int8_array.view(np.uint8)
flat_bytes   = uint8_array.tobytes()

print("Connecting to FPGA on COM8...")
try:
    with serial.Serial("COM8", 115200, timeout=2) as ser:
        print("Connected! Sending 784 bytes...")
        ser.write(flat_bytes)
        ser.flush()
        print("Transfer complete! Look at the FPGA 7-segment display.")
except Exception as e:
    print(f"Failed to communicate over COM8: {e}")
