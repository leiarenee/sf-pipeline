FROM public.ecr.aws/docker/library/python:3.9-slim

# Install Python Libraries
COPY requirements.txt  .
RUN  pip install -r requirements.txt 

# Install Git
RUN apt update && apt -y install git curl wget unzip jq rsync gettext-base rdfind uuid-runtime

# Install AWS Cli
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
  unzip awscliv2.zip && ./aws/install && rm awscliv2.zip

# Install Terraform
ARG TERRAFORM_VERSION
RUN wget https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip -O terraform.zip && \
  unzip terraform.zip && mv terraform /usr/local/bin/ && rm terraform.zip

# Install Terragrunt
ARG TERRAGRUNT_VERSION
RUN wget https://github.com/gruntwork-io/terragrunt/releases/download/v${TERRAGRUNT_VERSION}/terragrunt_linux_amd64 -O terragrunt && \
  chmod +x terragrunt && mv terragrunt /usr/local/bin/terragrunt

RUN useradd -ms /bin/bash app

USER app
WORKDIR /home/app
RUN mkdir .aws && touch .aws/credentials
# RUN mkdir .terraform.d && mkdir .terraform.d/plugin-cache

# Environment variables
ENV PYTHONPATH=src

# Copy Files
COPY src src
COPY infra/library/terragrunt terragrunt
COPY infra/library/terraform terraform
COPY infra/library/scripts scripts

# Copy Folder
COPY infra/docker/entrypoint .
COPY runner .

# SSH
RUN mkdir .ssh && touch .ssh/known_hosts
RUN ssh-keygen -R github.com
RUN ssh-keyscan -t rsa github.com >> ~/.ssh/known_hosts

ENTRYPOINT [ "./entrypoint" ]
CMD ["validate"]
