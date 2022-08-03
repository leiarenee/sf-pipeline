# CRE &amp; DevOps Trial Project Architecture

## Functional Requirements

* Application deployed needs to have some form of external state, a database or cache.
* On each commit to master, the application is built then deployed via any deployment approach.
* If the application fails to build or errors, then a rollback is performed.
* The audit history of build & deployments has to be visible in GIT, to allow for auditable history.
* All the dependent deployment of infrastructure has to be managed in code.

## Non Functional Requirements

* Deployment pipeline should be reliable, efficient and cost effective.

## Architecturel Discussion

The main purpose of the system is to act as a deployment pipeline. Alternative methods offered by Harshicorp is documented in [Running Terraform in Automation](https://learn.hashicorp.com/tutorials/terraform/automate-terraform?in=terraform/automation). They are:

* [Deploy Terraform infrastructure with CircleCI](https://learn.hashicorp.com/tutorials/terraform/circle-ci?in=terraform/automation)
* [Automate Terraform with GitHub Actions](https://learn.hashicorp.com/tutorials/terraform/github-actions?in=terraform/automation)

## GITOPS CICD Pipeline Architecture

### Design Proposal to create Pipeline in AWS

In this project I'll be demonstrating another aproach which uses github as a user interface while AWS Native services for running CI/CD Pipeline

### What is the motivation behind creating the pipeline in AWS

* Creating your own docker executer gives you more flexibility and control in your pipeline environment.
* Github actions is not a traditional pipeline environment and may need other executors to run complex tasks
* Using AWS native services will make your pipeline environment close to your AWS Production and ephemeral environments making it easy to share resources
* Having pipeline and deployment environments all under same provide will make us able to use of IAM Role based access control, making it more secure than using external pipelines. 
* We would like to try and see the result so that we compare solutions side by side.

### Components to be used creating the pipeline

* AWS Batch on Fargate as main Docker executer.
* AWS Step functions as main queuee system for orchestrating jobs such as plan, apply, destroy, validate with error handling and retrial and restoring state back to last working commit on error.
* AWS Cloudwatch and Xray inorder to log and trace pipeline events.
* AWS Secrets manager for storing and fetching secrets on demand.
* AWS S3 for storing and reusing pipeline artifacts.
* AWS SQS for delivering status messages about pipeline events.
* AWS Eventbridge for trigering jobs based on internal and external events.
* AWS Codebuild to remotely build docker images.
* AWS ECR as docker images repository.
* AWS Lambda (Containerized) to store functions to be called from inside step functions and docker executers.

### How it works?



![Gitops CICD Pipeline Architecture](../images/gitops-pipeline-diagram.png)