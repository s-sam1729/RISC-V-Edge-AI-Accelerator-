import tkinter as tk
from PIL import Image, ImageDraw, ImageOps
import torch
import torch.nn as nn
import torchvision.transforms as transforms
import os

class MNIST_MLP(nn.Module):
    def __init__(self):
        super().__init__()
        self.fc1 = nn.Linear(784, 128)
        self.fc2 = nn.Linear(128, 10)

    def forward(self, x):
        x = x.view(-1, 784)
        x = torch.relu(self.fc1(x))
        x = self.fc2(x)
        return x

class PCInferenceGUI:
    def __init__(self, root):
        self.root = root
        self.root.title("PC Local Inference Test")
        
        self.model = MNIST_MLP()
        model_path = "../quantize/mnist_model.pth"
        if os.path.exists(model_path):
            self.model.load_state_dict(torch.load(model_path))
            self.model.eval()
            print("Loaded PyTorch model successfully!")
        else:
            print(f"Error: Could not find {model_path}. Did you run quantize_weights.py first?")
        
        self.canvas = tk.Canvas(self.root, width=280, height=280, bg='black', cursor="cross")
        self.canvas.pack(pady=10)
        self.canvas.bind("<B1-Motion>", self.paint)
        
        btn_frame = tk.Frame(self.root)
        btn_frame.pack()
        
        tk.Button(btn_frame, text="Clear", command=self.clear_canvas, width=10).pack(side=tk.LEFT, padx=5)
        tk.Button(btn_frame, text="Predict on PC", command=self.predict, width=15, bg="lightblue").pack(side=tk.LEFT, padx=5)
        
        self.result_label = tk.Label(self.root, text="Draw a digit...", font=("Arial", 16))
        self.result_label.pack(pady=10)
        
        self.image = Image.new("L", (280, 280), "black")
        self.draw = ImageDraw.Draw(self.image)

    def paint(self, event):
        # Slightly thinner brush to match MNIST better
        x1, y1 = (event.x - 10), (event.y - 10)
        x2, y2 = (event.x + 10), (event.y + 10)
        self.canvas.create_oval(x1, y1, x2, y2, fill="white", outline="white")
        self.draw.ellipse([x1, y1, x2, y2], fill="white")

    def clear_canvas(self):
        self.canvas.delete("all")
        self.image = Image.new("L", (280, 280), "black")
        self.draw = ImageDraw.Draw(self.image)
        self.result_label.config(text="Draw a digit...")

    def process_image(self, img):
        # FIXED: Center the drawing exactly like the MNIST dataset does
        bbox = img.getbbox()
        if bbox is None:
            return img.resize((28, 28), Image.Resampling.BILINEAR)
            
        cropped = img.crop(bbox)
        
        # Scale largest dimension to 20 pixels
        w, h = cropped.size
        if w > h:
            new_w, new_h = 20, max(1, int(20 * (h / w)))
        else:
            new_w, new_h = max(1, int(20 * (w / h))), 20
            
        resized = cropped.resize((new_w, new_h), Image.Resampling.BILINEAR)
        
        # Paste into center of 28x28 canvas
        final_img = Image.new("L", (28, 28), "black")
        paste_x, paste_y = (28 - new_w) // 2, (28 - new_h) // 2
        final_img.paste(resized, (paste_x, paste_y))
        
        return final_img

    def predict(self):
        # Apply the new MNIST centering function
        img_centered = self.process_image(self.image)
        
        transform = transforms.Compose([
            transforms.ToTensor(),
            transforms.Normalize((0.5,), (0.5,))
        ])
        
        input_tensor = transform(img_centered)
        
        with torch.no_grad():
            output = self.model(input_tensor)
            prediction = torch.argmax(output).item()
            
            # --- NEW: Convert raw scores to percentages ---
            probabilities = torch.softmax(output, dim=1)[0] * 100
            confidence = probabilities[prediction].item()
            
            # Print raw scores and percentages to terminal
            print(f"Raw Logits: {output.numpy()[0]}")
            print(f"Probabilities: {probabilities.numpy()}")
            
        # Update the UI to show the Prediction AND Confidence!
        self.result_label.config(text=f"PC Predicts: {prediction} ({confidence:.1f}%)")

if __name__ == "__main__":
    root = tk.Tk()
    app = PCInferenceGUI(root)
    root.mainloop()