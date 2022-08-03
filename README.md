# CRE &amp; DevOps Trial Project

## Project Brief High Level Epic

Continuous Deployment of a Static Application via GitOps

### Solution Design

To be decided solely by the candidate, as long as it meets the requirements of the epic.

### Requirements

* Application deployed needs to have some form of external state, a database or cache. The application given as part of the technical loop can be used, but it’s not mandatory. - On each commit to master, the application is built then deployed via any deployment approach.
* If the application fails to build or errors, then a rollback is performed.
* The audit history of build & deployments has to be visible in GIT, to allow for auditable history.
* All the dependent deployment of infrastructure has to be managed in code. - Deployment of the application has to be publicly reachable.

### Stretch Requirements

* Ephemeral environments are created on each new pull request
* Any dependent infrastructure changes are also applied as part of any pull request


