FROM ubuntu:16.04
LABEL maintainer="nlkey2022@gmail.com"

RUN apt-get update && apt install git python python-pip unzip wget vim -y && \
    git clone https://github.com/graykode/aws-kubeadm-terraform && \
    cd aws-kubeadm-terraform

RUN wget https://releases.hashicorp.com/terraform/0.11.13/terraform_0.11.13_linux_amd64.zip && \
    unzip terraform_0.11.13_linux_amd64.zip && \
    rm terraform_0.11.13_linux_amd64.zip && \
    mv terraform /usr/bin && chmod +x /usr/bin/terraform

RUN cd /aws-kubeadm-terraform

WORKDIR /aws-kubeadm-terraform