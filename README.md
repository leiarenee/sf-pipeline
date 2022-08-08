# SF-GITOPS

## Project Brief High Level Epic

Continuous Deployment of a Static Application via GitOps

### Solution Design

AWS Step-functions will be used to enqueue and orchestrate on-demand terraform jobs which will be executed using AWS Batch on Fargate.

### Requirements

* Application deployed needs to have some form of external state, a database or cache. 
* On each commit to master, the application is built then deployed via any deployment approach.
* If the application fails to build or errors, then a rollback is performed.
* The audit history of build & deployments has to be visible in GIT, to allow for auditable history.
* All the dependent deployment of infrastructure has to be managed in code.
* Deployment of the application has to be publicly reachable.

### Stretch Requirements

* Ephemeral environments are created on each new pull request
* Any dependent infrastructure changes are also applied as part of any pull request

---

### Project Links

* [Architecture, System Design and Flow Diagrams](./architecture/README.md)
* [Project Board](https://github.com/users/leiarenee/projects/1)
* [Road Map](https://github.com/leiarenee/sf-pipeline/milestones?direction=asc&sort=due_date)

### Repositories

* [Pipeline Repository](https://github.com/leiarenee/sf-pipeline)
* [Infrastructure Repository](https://github.com/leiarenee/sf-infra)
* [Application Repository](https://github.com/leiarenee/sf-app)



