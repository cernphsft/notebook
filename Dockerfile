# Analogous to jupyter/notebook, based on SLC6.
# Installs Jupyter Notebook and IPython kernel from the current branch.
# Another Docker container should inherit with `FROM cernphsft/notebook`
# to run actual services.

FROM cern/slc6-base

MAINTAINER Enric Tejedor Saavedra <enric.tejedor.saavedra@cern.ch>

# Not essential, but wise to set the lang.
# Note: Users with other languages should set this in their derivative image
ENV LANGUAGE en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8
ENV PYTHONIOENCODING UTF-8

# Configure environment
ENV CONDA_DIR /opt/conda
ENV PATH $CONDA_DIR/bin:$PATH
ENV SHELL /bin/bash

RUN yum -y install yum-plugin-ovl # See https://github.com/CentOS/sig-cloud-instance-images/issues/15

# Install developer tools
RUN yum -y update
RUN yum -y install \
    bzip2 \
    gcc \
    gcc-c++ \
    git \
    kernel-devel \
    libcurl-openssl-devel \
    libffi-devel \
    ncurses-devel \
    nano \
    nodejs \
    npm \
    pandoc \
    patch \
    sqlite-devel \
    tar \
    texlive-latex \
    texlive-texmf-fonts \
    unzip \
    wget \
    which \
    zeromq3-devel \
    zlib-devel && yum clean all

# Install Latex packages (missing in SLC6, needed to convert notebooks to PDF)
WORKDIR /usr/share/texmf
RUN wget http://mirrors.ctan.org/install/macros/latex/contrib/adjustbox.tds.zip && \
    unzip -d . adjustbox.tds.zip && \ 
    rm adjustbox.tds.zip
RUN wget http://mirrors.ctan.org/install/macros/latex/contrib/collectbox.tds.zip && \
    unzip -d . collectbox.tds.zip && \
    rm collectbox.tds.zip
RUN mktexlsr

# Install Tini
RUN wget --quiet https://github.com/krallin/tini/releases/download/v0.10.0/tini && \
    echo "1361527f39190a7338a0b434bd8c88ff7233ce7b9a4876f3315c22fce7eca1b0 *tini" | sha256sum -c - && \
    mv tini /usr/local/bin/tini && \
    chmod +x /usr/local/bin/tini

# Install Python 2.7
RUN mkdir /tmp/pytmp
WORKDIR /tmp/pytmp
RUN wget http://www.python.org/ftp/python/2.7.13/Python-2.7.13.tgz && \
    tar xvzf Python-2.7.13.tgz
WORKDIR /tmp/pytmp/Python-2.7.13
RUN ./configure --enable-shared && \
    make install
ENV LD_LIBRARY_PATH /usr/local/lib/
RUN echo "LD_LIBRARY_PATH=$LD_LIBRARY_PATH" >> /etc/environment

# Install Python 3
WORKDIR /tmp/pytmp
RUN wget https://www.python.org/ftp/python/3.6.1/Python-3.6.1.tgz && \
    tar xzvf Python-3.6.1.tgz
WORKDIR /tmp/pytmp/Python-3.6.1
RUN ./configure --enable-shared && \
    make install

# Cleanup
RUN rm -rf /tmp/pytmp

# Install the recent pip release
RUN curl -O https://bootstrap.pypa.io/get-pip.py && \
    python2 get-pip.py && \
    python3 get-pip.py && \
    rm get-pip.py

# Install conda as jovyan and check the md5 sum provided on the download site
ENV MINICONDA_VERSION 4.3.21
RUN cd /tmp && \
    mkdir -p $CONDA_DIR && \
    wget --quiet https://repo.continuum.io/miniconda/Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh && \
    echo "c1c15d3baba15bf50293ae963abef853 *Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh" | md5sum -c - && \
    /bin/bash Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh -f -b -p $CONDA_DIR && \
    rm Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh && \
    $CONDA_DIR/bin/conda config --system --prepend channels conda-forge && \
    $CONDA_DIR/bin/conda config --system --set auto_update_conda false && \
    $CONDA_DIR/bin/conda config --system --set show_channel_urls true && \
    $CONDA_DIR/bin/conda update --all && \
    conda clean -tipsy

# Install Jupyter Notebook and Hub
RUN conda install --quiet --yes \
    'notebook=5.0.*' \
    'jupyterhub=0.7.*' \
    'jupyterlab=0.24.*' \
    && conda clean -tipsy

# Add a notebook profile
RUN mkdir -p -m 700 /root/.jupyter/ && \
    echo "c.NotebookApp.ip = '*'" >> /root/.jupyter/jupyter_notebook_config.py

VOLUME /notebooks
WORKDIR /notebooks

EXPOSE 8888

ENTRYPOINT ["tini", "--"]
CMD ["jupyter", "notebook"]

