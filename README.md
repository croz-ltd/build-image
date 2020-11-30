# Build Image
[![Docker Repository on Quay](https://quay.io/repository/crozltd/build-image/status "Docker Repository on Quay")](https://quay.io/repository/crozltd/build-image)

An image ready to be used by any CI (tested on Gitlab CI).

## Available/installed tools

| Tool | Version |
| --- | --- |
| yq | 3 |
| jq | 1.6 |
| buildah | 1.8.3 |
| helm | 3.4.0 |
| skopeo | 0.1.36 |
| argocd | v1.7.6 |
| kustomize | 2.1.0 | 
| kubeval | 0.15.0 |
| go | 1.15.3 |
| oc | 3.11.0 (`use_oc311`), 4 (`use_oc4`) |

## CA Trust

If needed, you can configure your Dockerfile to fetch and trust certificates from certain hosts.
All you have to do is to generate `trust-hostports.txt` file with lines containing hosts in `[http(s)]<host>:<port>` format, eq.
```
my.cool.host:443
mysecond.cool.host:8443
```  

Your `Dockerfile` could look like this:

```
FROM quay.io/crozltd/build-image:latest

COPY trust-hostports.txt ./

RUN ./trustcerts.sh
```

# OpenShift CLI

There are two versions available, 3.11 and 4. In order to activate the right invoke these commands before usage:
- `use_oc311` for version 3.11
- `use_oc4` for version 4
