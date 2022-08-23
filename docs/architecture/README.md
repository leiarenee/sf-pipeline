# CRE &amp; DevOps Trial Project Architecture

## Functional Requirements

* Application deployed needs to have some form of external state, a database or cache.
* On each commit to master, the application is built then deployed via any deployment approach.
* If the application fails to build or errors, then a rollback is performed.
* The audit history of build & deployments has to be visible in GIT, to allow for auditable history.
* All the dependent deployment of infrastructure has to be managed in code.
* Deployment of the application has to be publicly reachable.
* Ephemeral environments are created on each new pull request
* Any dependent infrastructure changes are also applied as part of any pull request

## Non Functional Requirements

* Deployment pipeline should be reliable, efficient and cost effective.

## Architectural Discussion

The main purpose of the system is to act as a deployment pipeline. Alternative methods offered by Harshicorp is documented in [Running Terraform in Automation](https://learn.hashicorp.com/tutorials/terraform/automate-terraform?in=terraform/automation). They are:

* [Deploy Terraform infrastructure with CircleCI](https://learn.hashicorp.com/tutorials/terraform/circle-ci?in=terraform/automation)
* [Automate Terraform with GitHub Actions](https://learn.hashicorp.com/tutorials/terraform/github-actions?in=terraform/automation)

## Design Proposal to create Pipeline in AWS

In this project I'll be demonstrating another aproach which uses github as user interface, github actions as main pipeline coordinating events and tasks while AWS native services for running terraform jobs in fargate docker executor.

### What is the motivation behind creating the core TF pipeline in AWS

* Creating your own docker executer gives you more flexibility and control in your pipeline environment.
* Github actions is not a traditional pipeline environment and may need other executors to run complex tasks
* Using AWS native services will make your pipeline environment close to your AWS Production and ephemeral environments making it easy to share resources.
* Having pipeline and deployment environments all under same provider will make us able to use of IAM Role based access control, making it more secure than using external pipelines. 
* We would like to try and see the result so that we can compare solutions side by side with other approaches. 

### Components to be used creating the pipeline

* AWS Batch on Fargate as main Docker executer.
* AWS Step functions as main queuee system for orchestrating jobs such as plan, apply, destroy, validate with error handling and retrial mechanisms.
* AWS Cloudwatch and X-ray inorder to log and trace pipeline events.
* AWS Secrets manager for storing and fetching secrets on demand.
* AWS S3 for storing and re-using pipeline artifacts.
* AWS SQS for delivering status messages about pipeline events.
* AWS Eventbridge for trigering jobs based on internal and external events.
* AWS Codebuild to remotely build docker images.
* AWS ECR as docker image repository.
* AWS Lambda (Containerized) to store functions to be called from inside step functions and docker executers.

### How it works?

One of the main objectives of the project is to create the pipeline using GITOPS approach thereby it is essential to define what GITOPS means and how it differantiates from convetional approaches.

### Principles of GITOPS

Ref : [Weaveworks](https://www.weave.works/technologies/gitops/) 

1. The entire system described declaratively.
2. The canonical desired system state versioned in Git.
3. Approved changes that can be automatically applied to the system. 
4. Software agents to ensure correctness and alert on divergence. (_neglected in this project_)

### Types of Gitops

Ref: [gitops.tech](https://www.gitops.tech/)

1. Pull based
2. Push based

While principles 1 to 3 are common for both versions, number 4 is only valid for pull based gitops. In this project we will use __Push based Gitops__ hence we can ignore final principle in our architecture.

### Push Based Gitops Flow

![Push Based Gitops Flow](../images/push-based-gitops.png)

---

### Flow Diagram for the Project

![Gitops CICD Pipeline Architecture](../images/gitops-pipeline-diagram.png)

---

## Work Flows

AWS Step-functions will be used to enqueue and orchestrate on-demand terraform jobs which will be executed using AWS Batch on Fargate.

### PLAN

  * Trigger : Pull Request
  * Steps:
    * Terraform plan
  * Target Environment : Merge Environment 
  * Output : Publish Plan on PR Page - Send Slack notification

### PLAN - APPLY

  * Trigger : Commit to Master
  * Steps:
    * Terreform plan
    * Wait for approval
    * Terraform apply
  * On Error:
    * Checkout to last working commit
    * Terraform apply
  * Target Environment : Merge Environment 
  * Output: Send Slack Notification

### APPLY EPHEMERAL

  * Trigger : Manual
  * Steps: 
    * Terraform Apply
    * Schedule Cron Job to destroy
  * On Error:
    * Terraform Destroy
  * Target Environment : Ephemeral Testing/Dev Environments
  * Output: Slack Notification

### Other Workflows

  * Modify Cron
  * Pass terraform command

---

## INPUTS

  * Infrastructure Repository
  * Commit [hash|branch|tag|ref] 
  * Target Environment (AWS account ID)
  * Pipeline Command [plan|apply|ephemeral|cron|<custom>]
  * Batch Job Definition ARN
  * Batch Job Queue ARN
  * User Email 
  * Pull Request ID (Optional)
  * Time to Live (Optional)
