import tkinter as tk
from tkinter import messagebox
import numpy as np
from PIL import Image, ImageDraw
import socket

CANVAS_SIZE = 280   
BRUSH_SIZE = 20     
SIM_PORT = 9999     # Port used by tb_cosim.py

class NeuroCoreSimGUI:
    def __init__(self, root):
        self.root = root
        self.root.title("NeuroCore: SIMULATION Input")
        self.root.geometry("400x500")
        
        tk.Label(self.root, text="Simulation Mode", font=("Helvetica", 12, "bold"), fg="blue").pack(pady=5)
        tk.Label(self.root, text="1. Run 'python run_sim.py'\n2. Draw here and click 'Send to Simulation'", justify=tk.CENTER).pack()

        self.canvas = tk.Canvas(self.root, width=CANVAS_SIZE, height=CANVAS_SIZE, bg='black', cursor="cross")
        self.canvas.pack(pady=10)
        self.canvas.bind("<B1-Motion>",      self.paint)
        self.canvas.bind("<ButtonRelease-1>", self.reset_brush)

        btn_frame = tk.Frame(self.root)
        btn_frame.pack(pady=5)
        tk.Button(btn_frame, text="Clear", command=self.clear_canvas, width=10).pack(side=tk.LEFT, padx=5)
        tk.Button(btn_frame, text="Send to Simulation", command=self.send_to_sim, width=20, bg="blue", fg="white").pack(side=tk.LEFT, padx=5)

        self.status_var = tk.StringVar(value="Status: Waiting...")
        tk.Label(self.root, textvariable=self.status_var, font=("Helvetica", 10)).pack(pady=10)

        self.image = Image.new("L", (CANVAS_SIZE, CANVAS_SIZE), color=0)
        self.draw  = ImageDraw.Draw(self.image)
        self.last_x, self.last_y = None, None

    def paint(self, event):
        x, y = event.x, event.y
        if self.last_x is not None and self.last_y is not None:
            self.canvas.create_line((self.last_x, self.last_y, x, y), fill='white', width=BRUSH_SIZE, capstyle=tk.ROUND, smooth=tk.TRUE)
            self.draw.line((self.last_x, self.last_y, x, y), fill=255, width=BRUSH_SIZE, joint="curve")
        self.last_x, self.last_y = x, y

    def reset_brush(self, event):
        self.last_x, self.last_y = None, None

    def clear_canvas(self):
        self.canvas.delete("all")
        self.image  = Image.new("L", (CANVAS_SIZE, CANVAS_SIZE), color=0)
        self.draw   = ImageDraw.Draw(self.image)
        self.status_var.set("Status: Cleared")

    def process_image(self, img):
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

    def send_to_sim(self):
        img_centered = self.process_image(self.image)
        pixel_array  = np.array(img_centered, dtype=np.float32) / 255.0
        int8_array   = np.clip(np.round(pixel_array * 254.0 - 127.0), -127, 127).astype(np.int8)
        flat_bytes   = int8_array.tobytes()

        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.settimeout(2)
                s.connect(('127.0.0.1', SIM_PORT))
                s.sendall(flat_bytes)
            self.status_var.set("Status: Image sent to Simulation!")
        except Exception as e:
            self.status_var.set(f"Status: Sim Error - {e}")
            messagebox.showerror("Sim Error", "Could not connect to Simulation.\nEnsure 'python run_sim.py' is currently running.")

if __name__ == "__main__":
    root = tk.Tk()
    app  = NeuroCoreSimGUI(root)
    root.mainloop()
