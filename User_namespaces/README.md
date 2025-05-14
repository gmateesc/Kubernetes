
# Overview

This page describe the relationship between K8s settings such as the
securityContext attribyes

- runAsUser

- allowPrivilegeEscalation

- capabilities


and

- the operations that the container user can perform in the container

- the access the container has to the the host root file system, in the context of UID mapping



## K8s versions

Kubernetes versions prior to 1.33.0 do no support user namespaces.

Therefore, root user on the container is mapped to root on the
node where the container runs, which is a security hole that
must be avoided by

- not running containers as root: this can be achieved
  by specifying, e.g.,
```
     securityContext.runAsUser: 1000 
     securityContext.runAsGroup: 1000
```

- disabling privilege escalation
```
     securityContext.allowPrivilegeEscalation: false 
```


### Matrix of access versus settings


| Container  |allowPrivilegeEscalation|  capabilities  | sys_admin on   | access to host  |
|  user      |                        |                |   container    | root FS         | 
| :--------- | :--------------------: | :------------: | :------------: | :-------------: |
| root       |                        |                |    yes         | yes, if no UID map |
| 1000       |     true               |                | yes, with sudo | yes, if no UID map |
|            |     true               |  SYS_ADMIN     | yes, wo sudo   |      no        |
|            |     false              |  SYS_ADMIN     |    no          |      no        |

