FROM ghcr.io/allenai/pytorch:2.5.1-cuda11.8-python3.11-v2025.03.21

# Install conda. We give anyone in the users group the ability to run
# conda commands and install packages in the base (default) environment.
# Things installed into the default environment won't persist, but we prefer
# convenience in this case and try to make sure the user is aware of this
# with a message that's printed when the session starts.
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-py310_23.1.0-1-Linux-x86_64.sh \
    && echo "32d73e1bc33fda089d7cd9ef4c1be542616bd8e437d1f77afeeaf7afdb019787 Miniconda3-py310_23.1.0-1-Linux-x86_64.sh" \
        | sha256sum --check \
    && bash Miniconda3-py310_23.1.0-1-Linux-x86_64.sh -b -p /opt/miniconda3 \
    && rm Miniconda3-py310_23.1.0-1-Linux-x86_64.sh

ENV PATH=/opt/miniconda3/bin:/opt/miniconda3/condabin:$PATH
# Install a few additional utilities via pip
RUN /opt/miniconda3/bin/pip install --no-cache-dir \
    gpustat \
    jupyter \
    beaker-gantry \
    oocmap

WORKDIR /stage/

# install google cloud sdk
RUN apt-get update && apt-get install -y gnupg curl
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg && apt-get update -y && apt-get install google-cloud-cli -y

# TODO When updating flash-attn or torch in the future, make sure to update the version in the requirements.txt file. 
ENV HF_HUB_ENABLE_HF_TRANSFER=1

## TORCHTUNE
# RUN pip install --upgrade pip "setuptools<70.0.0" wheel 
# COPY datagen datagen
# COPY deps deps

# # install the package in editable mode
# COPY pyproject.toml .
# COPY MANIFEST.in .
# RUN pip install -e .
# # add script that will do this for all in deps
# RUN pip install -e deps/torchtune
# COPY .git/ ./.git/

## AXOLOTL
COPY . .
RUN pip install jinja2
RUN pip install numpy
RUN conda install mkl mkl-devel
RUN VLLM_USE_PRECOMPILED=1 pip install -e .
