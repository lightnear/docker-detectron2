FROM nvidia/cuda:11.1-cudnn8-runtime-ubuntu20.04

LABEL maintainer="lightnear<lightnear@qq.com>"

ENV TZ=Asia/Shanghai
ENV LANG en_US.utf8
ENV DEBIAN_FRONTEND noninteractive

RUN sed -i s@/archive.ubuntu.com/@/mirrors.aliyun.com/@g /etc/apt/sources.list \
  && sed -i s@/security.ubuntu.com/@/mirrors.aliyun.com/@g /etc/apt/sources.list
# sed -i s@/developer.download.nvidia.cn/compute/cuda/repos/@/mirrors.aliyun.com/nvidia-cuda/@g /etc/apt/sources.list.d/cuda.list && \
# sed -i s@/developer.download.nvidia.com/compute/cuda/repos/@/mirrors.aliyun.com/nvidia-cuda/@g /etc/apt/sources.list.d/cuda.list && \
# sed -i s@/developer.download.nvidia.cn/@/developer.download.nvidia.com/@g /etc/apt/sources.list.d/nvidia-ml.list

RUN apt update \
  && apt install -y tzdata \
  && ln -fs /usr/share/zoneinfo/${TZ} /etc/localtime \
  && echo ${TZ} > /etc/timezone \
  && dpkg-reconfigure --frontend noninteractive tzdata \
  && apt install -y locales \
  && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 \
  && apt install -y rsync curl wget sudo git bzip2 \
  && apt install -y build-essential ninja-build ca-certificates ccache cmake libjpeg-dev libpng-dev \
  && rm -rf /var/lib/apt/lists/*

# Create a working directory
RUN mkdir /app
WORKDIR /app

# create a non-root user
ARG USER_ID=9000
RUN useradd --system -u ${USER_ID} -m -s /bin/bash appuser \
  && usermod -a -G sudo appuser \
  && chown -R appuser:appuser /app \
  && echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
USER appuser

# Install Miniconda and Python 3.8
ENV CONDA_AUTO_UPDATE_CONDA=false
ENV PATH=/home/appuser/miniconda/bin:$PATH
ARG PYTHON_VERSION=3.8
RUN curl -fsSL -v -o ~/miniconda.sh -O  https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh  && \
  chmod +x ~/miniconda.sh && \
  bash ~/miniconda.sh -b -p ~/miniconda && \
  rm ~/miniconda.sh && \
  conda init && \
  conda install -y python=${PYTHON_VERSION} conda-build ipykernel ipython && \
  conda clean -ya

RUN pip install --user cmake \
  && pip install --user cython pyyaml matplotlib scipy opencv-python tqdm augmentor tensorboard numpy pandas ibm_db \
  && conda install -y pytorch torchvision torchaudio cudatoolkit=11.1 -c pytorch-lts -c nvidia \
  && python -m pip install detectron2==0.4 -f https://dl.fbaipublicfiles.com/detectron2/wheels/cu111/torch1.8/index.html \
  && conda clean -ya \
  && pip cache purge

RUN conda install -y notebook -y -c conda-forge \
  && conda install -y nb_conda \
  && conda clean -ya \
  && jupyter notebook --generate-config \
  && echo "c.NotebookApp.ip = '*'" > ~/.jupyter/jupyter_notebook_config.py \
  && echo "c.NotebookApp.open_browser = False" >> ~/.jupyter/jupyter_notebook_config.py \
  && echo "c.NotebookApp.port = 8888" >> ~/.jupyter/jupyter_notebook_config.py \
  && echo "c.NotebookApp.token = '123456'" >> ~/.jupyter/jupyter_notebook_config.py

# set FORCE_CUDA because during `docker build` cuda is not accessible
ENV FORCE_CUDA="1"
# Set a fixed model cache directory. $HOME/.torch/fvcore_cache
ENV FVCORE_CACHE="/.torch/fvcore_cache"

EXPOSE 8888
VOLUME /app
VOLUME /.torch/fvcore_cache

CMD jupyter notebook

