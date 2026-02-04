# Base: Google's VS Code (Code OSS)
FROM us-central1-docker.pkg.dev/cloud-workstations-images/predefined/code-oss:latest

# Environment Setup
ENV DEBIAN_FRONTEND=noninteractive \
    PIP_BREAK_SYSTEM_PACKAGES=1 \
    HOME=/home/user

USER root

# 1. Install System Tools & Jupyter Prerequisites
# Fix: Remove broken Yarn repo list that comes with the base image
RUN rm -f /etc/apt/sources.list.d/yarn.list && \
    apt-get update && \
    apt-get install -yq --no-install-recommends \
    git build-essential python3-dev python3-pip && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# 2. Install Python Libraries & JupyterLab
COPY requirements.txt /tmp/requirements.txt
RUN pip3 install -U pip --no-cache-dir && \
    pip3 install --no-cache-dir -r /tmp/requirements.txt && \
    pip3 install --no-cache-dir jupyterlab

# 3. Add the "Repo Cloner" Script
# We create a script that will run every time you log in
COPY clone_repos.sh /usr/local/bin/clone_repos.sh
RUN chmod +x /usr/local/bin/clone_repos.sh

# 4. Configure VS Code to run the cloner on startup
# We simply append it to the user's .bashrc so it runs when the terminal opens
RUN echo "/usr/local/bin/clone_repos.sh" >> /etc/bash.bashrc

# Switch back to standard user
USER user
WORKDIR /home/user
