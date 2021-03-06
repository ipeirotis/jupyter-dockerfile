FROM ubuntu:latest

# Configure environment
ENV LANGUAGE en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8
ENV PYTHONIOENCODING UTF-8
ENV SHELL=/bin/bash
ENV NB_USER="ubuntu"
ENV NB_UID="1000"
ENV NB_GID="100"    

ARG NETRC
ARG DEBIAN_FRONTEND=noninteractive

# We stil setup everything as root, change permissions later
USER root

RUN apt-get -qy update && \
        apt-get -qy dist-upgrade && \
        apt-get -qy upgrade

# Install all OS dependencies for notebook server that starts but lacks all
# features (e.g., download as all possible file formats)
RUN apt-get install -yq --no-install-recommends \
    wget \
    bzip2 \
    ca-certificates \
    sudo \
    locales \
    fonts-liberation \
    run-one       
        
RUN apt-get install -yq  \
        nano \
        cron \
        curl \
        git \
        vim \
        jq

RUN apt-get -qy install \
        build-essential \
        python3-dev \
        python3-pip 

RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen

RUN dpkg-reconfigure locales
    
RUN apt-get clean && \
        rm -rf /var/lib/apt/lists/*

# Add Tini. Tini operates as a process subreaper for jupyter. This prevents
# kernel crashes.
ENV TINI_VERSION v0.19.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /usr/bin/tini
RUN chmod +x /usr/bin/tini

# Copy a script that we will use to correct permissions after running certain commands
COPY fix-permissions /usr/local/bin/fix-permissions
RUN chmod a+rx /usr/local/bin/fix-permissions
COPY start-notebook.sh /usr/local/bin/
RUN chmod a+rx /usr/local/bin/start-notebook.sh

# Enable prompt color in the skeleton .bashrc before creating the default NB_USER
RUN sed -i 's/^#force_color_prompt=yes/force_color_prompt=yes/' /etc/skel/.bashrc

# Create NB_USER wtih name jovyan user with UID=1000 and in the 'users' group
# and make sure these dirs are writable by the `users` group.
RUN echo "auth requisite pam_deny.so" >> /etc/pam.d/su && \
    sed -i.bak -e 's/^%admin/#%admin/' /etc/sudoers && \
    sed -i.bak -e 's/^%sudo/#%sudo/' /etc/sudoers && \
    useradd -m -s /bin/bash -N -u $NB_UID $NB_USER && \
    chmod g+w /etc/passwd && \
    fix-permissions /home/$NB_USER

RUN echo "ALL  ALL = (ALL) NOPASSWD: ALL" >> /etc/sudoers

# Setup work directory
RUN mkdir -p /home/$NB_USER/notebooks
RUN chown -R $NB_USER:$NB_GID /home/$NB_USER
RUN fix-permissions /home/$NB_USER

# install latest version of pip
RUN pip3 install -U pip

# Code formatter and linter
RUN pip3 install \
        black \
        flake8 \
        flake8-nb

# Code for interacting with MySQL
RUN pip3 install \
        PyMySQL \
        sqlalchemy \
        sql_magic

# add standard data science libraries
RUN pip3 install \
    numpy \
    scipy \
    matplotlib \
    pandas \
    openpyxl \
    seaborn \
    statsmodels \
    scikit-learn

# add libraries for teaching web APIs
RUN pip3 install \
    requests \
    Flask
    
# add libraries for NLP
RUN pip3 install \
    spacy \
    nltk
    
# add libraries for Web crawling
RUN pip3 install \
    bs4   
    
# install basic Python libraries to run Jupyter
RUN pip3 install \
    jupyter \
    notebook \
    nbformat \
    nbstripout \
    jupyterlab

RUN pip3 

# Enable extensions
RUN pip3 install jupyter_contrib_nbextensions

COPY jupyter_notebook_config.py /etc/jupyter/
RUN echo "c.NotebookApp.password = 'sha1:44967f2c7dbb:4ae5e013fa8bae6fd8d4b8fa88775c0c5caeffbf'" >> /etc/jupyter/jupyter_notebook_config.py
RUN echo "c.NotebookApp.notebook_dir = '/home/ubuntu/notebooks'" >> /etc/jupyter/jupyter_notebook_config.py

USER $NB_UID
ENV HOME=/home/$NB_USER
ENV PATH=$HOME/.local/bin:$PATH
WORKDIR $HOME

RUN echo "$NETRC" > $HOME/.netrc
RUN chmod 600 $HOME/.netrc

RUN jupyter contrib nbextension install --user

RUN jupyter nbextension enable collapsible_headings/main
RUN jupyter nbextension enable exercise2/main
RUN jupyter nbextension enable spellchecker/main

# Install Black as an extension
RUN jupyter nbextension install https://github.com/drillan/jupyter-black/archive/master.zip --user
RUN jupyter nbextension enable jupyter-black-master/jupyter-black

EXPOSE 8888

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["start-notebook.sh"]
