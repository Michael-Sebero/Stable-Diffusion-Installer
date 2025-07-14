## How to Install
```
git clone https://github.com/Michael-Sebero/Stable-Diffusion-Installer

cd /home/$USER/Stable-Diffusion-Installer && sh installer.sh
```

## How to Use
Poetry:
```
cd ComfyUI && poetry run python main.py
```
Pyenv:
```
cd ComfyUI && source venv/bin/activate && python main.py
```
Venv:
```
cd ComfyUI && source venv/bin/activate && python main.py
```

## Post-install
* Download Stable Diffusion models (checkpoints) and place them in `models/checkpoints/`
* Optionally download VAE files and place them in `models/vae/`
* Run ComfyUI using the command shown above.
* Open your browser to http://localhost:8188 to access ComfyUI.
