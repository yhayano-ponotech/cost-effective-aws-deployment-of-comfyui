FROM nvidia/cuda:12.3.1-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=America/Los_Angeles

# Install dependencies
RUN apt-get update && apt-get install -y \
    git \
    make build-essential libssl-dev zlib1g-dev \
    libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm \
    libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev git git-lfs  \
    ffmpeg libsm6 libxext6 cmake libgl1-mesa-glx \
    && rm -rf /var/lib/apt/lists/* \
    && git lfs install

# Create and switch to a new user
ENV HOME=/home/sagemaker-user \
    PATH=/home/sagemaker-user/.local/bin:$PATH

# Pyenv and Python setup
RUN curl https://pyenv.run | bash
ENV PATH=$HOME/.pyenv/shims:$HOME/.pyenv/bin:$PATH
ARG PYTHON_VERSION=3.10.12
RUN pyenv install $PYTHON_VERSION && \
    pyenv global $PYTHON_VERSION && \
    pyenv rehash && \
    pip install --no-cache-dir --upgrade pip setuptools wheel 

# Set the working directory
WORKDIR /home/sagemaker-user/opt/ComfyUI

# Clone ComfyUI directly into /home/user/opt/ComfyUI
RUN git clone --depth 1 https://github.com/comfyanonymous/ComfyUI .

# Create a Python virtual environment in a directory
ENV TEMP_VENV_PATH=/home/sagemaker-user/opt/ComfyUI/.venv
RUN python -m venv $TEMP_VENV_PATH

RUN . $TEMP_VENV_PATH/bin/activate && pip install xformers!=0.0.18 --no-cache-dir -r requirements.txt --extra-index-url https://download.pytorch.org/whl/cu121

# Clone ComfyUI-Manager and install its requirements
RUN mkdir -p custom_nodes/ComfyUI-Manager && \
    git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Manager custom_nodes/ComfyUI-Manager && \
    . $TEMP_VENV_PATH/bin/activate && pip install --no-cache-dir --upgrade torch torchvision GitPython && \
    pip install -r custom_nodes/ComfyUI-Manager/requirements.txt

# Copy the configuration file
COPY comfyui_config/extra_model_paths.yaml ./extra_model_paths.yaml

CMD ["bash", "-c", "source /home/sagemaker-user/opt/ComfyUI/.venv/bin/activate && exec python /home/sagemaker-user/opt/ComfyUI/main.py --listen 0.0.0.0 --port 8181 --output-directory /home/sagemaker-user/opt/ComfyUI/output/"]
