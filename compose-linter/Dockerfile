FROM python:3.7

ENV DEBIAN_FRONTEND=noninteractive

COPY requirements.txt /tmp/pip-tmp/
# Configure apt and install packages
RUN apt-get update \
    && pip --disable-pip-version-check --no-cache-dir install -r /tmp/pip-tmp/requirements.txt \
    && rm -rf /tmp/pip-tmp \
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

COPY main.py /

ENTRYPOINT ["/usr/local/bin/python", "/main.py"]