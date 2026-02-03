# Use a pinned version for stability
FROM ubuntu:22.04

# Configure environment
ENV DEBIAN_FRONTEND=noninteractive \
    LANGUAGE=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    PYTHONIOENCODING=UTF-8 \
    SHELL=/bin/bash \
    NB_USER="ubuntu" \
    NB_UID="1000" \
    NB_GID="100" \
    # Fix for PEP 668: Allow pip to install globally in container
    PIP_BREAK_SYSTEM_PACKAGES=1

# WARN: Passing secrets as ARG leaves them in the image history.
ARG NETRC

# Shell safety settings
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Switch to root for installation
USER root

# 1. Install System Dependencies
# Combined into one block to reduce image size
RUN apt-get -qy update && \
    apt-get upgrade --yes && \
    apt-get install -yq --no-install-recommends \
    # System & Build Tools
    wget bzip2 ca-certificates sudo locales fonts-liberation \
    nano cron curl git tzdata less openssh-client vim jq \
    tini run-one build-essential python3-dev python3-pip \
    # LaTeX / PDF generation
    pandoc texlive-xetex texlive-fonts-recommended texlive-plain-generic \
    cm-super dvipng ffmpeg && \
    # Locale generation
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen && \
    dpkg-reconfigure locales && \
    # Cleanup
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 2. Copy Helper Scripts
COPY fix-permissions /usr/local/bin/fix-permissions
COPY start-notebook.sh /usr/local/bin/
RUN chmod a+rx /usr/local/bin/fix-permissions /usr/local/bin/start-notebook.sh

# 3. User & Permission Setup
RUN sed -i 's/^#force_color_prompt=yes/force_color_prompt=yes/' /etc/skel/.bashrc && \
    echo "auth requisite pam_deny.so" >> /etc/pam.d/su && \
    sed -i.bak -e 's/^%admin/#%admin/' /etc/sudoers && \
    sed -i.bak -e 's/^%sudo/#%sudo/' /etc/sudoers && \
    # Create user if not exists
    if ! id -u $NB_UID > /dev/null 2>&1; then \
        useradd -m -s /bin/bash -N -u $NB_UID $NB_USER; \
    fi && \
    chmod g+w /etc/passwd && \
    echo "ALL  ALL = (ALL) NOPASSWD: ALL" >> /etc/sudoers && \
    # Setup work directory
    mkdir -p /home/$NB_USER/notebooks && \
    chown -R $NB_USER:$NB_GID /home/$NB_USER && \
    fix-permissions /home/$NB_USER

# 4. Install Python Dependencies
# We upgrade pip first, then install from requirements.txt
COPY requirements.txt /tmp/requirements.txt
RUN pip3 install -U pip --no-cache-dir && \
    pip3 install --no-cache-dir -r /tmp/requirements.txt

# 5. Jupyter Configuration
COPY overrides.json /opt/conda/share/jupyter/lab/settings/
COPY jupyter_notebook_config.py /etc/jupyter/

RUN echo "c.NotebookApp.password = 'sha1:44967f2c7dbb:4ae5e013fa8bae6fd8d4b8fa88775c0c5caeffbf'" >> /etc/jupyter/jupyter_notebook_config.py && \
    echo "c.NotebookApp.notebook_dir = '/home/ubuntu/notebooks'" >> /etc/jupyter/jupyter_notebook_config.py && \
    echo "c.Completer.use_jedi = False" >> /etc/jupyter/jupyter_notebook_config.py

# 6. Finalize
# Build matplotlib font cache
RUN MPLBACKEND=Agg python3 -c "import matplotlib.pyplot" && \
    fix-permissions "/home/${NB_USER}"

# Switch to user
USER $NB_UID
ENV HOME=/home/$NB_USER
ENV PATH=$HOME/.local/bin:$PATH
WORKDIR $HOME

# Handle NETRC (Optional)
RUN if [ -n "$NETRC" ]; then \
        echo "$NETRC" > $HOME/.netrc && chmod 600 $HOME/.netrc; \
    fi

EXPOSE 8888
ENTRYPOINT ["/usr/bin/tini", "-g", "--"]
CMD ["start-notebook.sh"]
