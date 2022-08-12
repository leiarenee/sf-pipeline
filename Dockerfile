#FROM python:3.9-slim
FROM public.ecr.aws/docker/library/python:3.9-slim

# Install Python Libraries
COPY requirements.txt  .
RUN  pip install -r requirements.txt 

# Install Git
RUN apt update && apt -y install git curl wget unzip jq gettext-base rdfind uuid-runtime

# Install AWS Cli
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
  unzip awscliv2.zip && ./aws/install && rm awscliv2.zip

# Install Terraform
# RUN TERRAFORM_VER=`curl -s https://api.github.com/repos/hashicorp/terraform/releases/latest |  grep tag_name | cut -d: -f2 | tr -d \"\,\v | awk '{$1=$1};1'` && \
RUN TERRAFORM_VER=1.1.2 && \
  wget https://releases.hashicorp.com/terraform/${TERRAFORM_VER}/terraform_${TERRAFORM_VER}_linux_amd64.zip -O terraform.zip && \
  unzip terraform.zip && mv terraform /usr/local/bin/ && rm terraform.zip

# Install Terragrunt
# RUN TERRAGRUNT_VER=`curl -s https://api.github.com/repos/gruntwork-io/terragrunt/releases/latest |  grep tag_name | cut -d: -f2 | tr -d \"\,\v | awk '{$1=$1};1'` && \
RUN TERRAGRUNT_VER=0.35.16 && \
  wget https://github.com/gruntwork-io/terragrunt/releases/download/v${TERRAGRUNT_VER}/terragrunt_linux_amd64 -O terragrunt && \
  chmod +x terragrunt && mv terragrunt /usr/local/bin/terragrunt

RUN useradd -ms /bin/bash app

USER app
WORKDIR /home/app
RUN mkdir .aws && touch .aws/credentials
RUN mkdir .terraform.d && mkdir .terraform.d/plugin-cache

# Environment variables
ENV PYTHONPATH=src

# Copy Files
COPY src src
COPY entrypoint .
COPY run-pipeline .

ENTRYPOINT [ "./entrypoint" ]
CMD ["validate"]
