# Frappe Operator 1-Click for DigitalOcean Kubernetes

Installs the [Frappe Operator](https://github.com/vyogotech/frappe-operator) on a
DigitalOcean Kubernetes cluster. The operator turns Frappe and ERPNext into
declarative Kubernetes resources: describe a bench and its sites in YAML, and
the operator automatically provisions databases, runs migrations, takes backups,
and installs apps.

It natively supports both **MariaDB** and **PostgreSQL** database engines out of the box.

## Prerequisites

1. **Helm 3** and `kubectl` on your local machine.
2. **A DigitalOcean Kubernetes cluster**, with kubeconfig configured.
3. **At least two nodes with 2 GB+ RAM** (or one 4 GB+ node).

## What gets installed

- **Frappe Operator** in `frappe-operator-system` namespace.
- **MariaDB Operator**, for automatic provisioning of MariaDB site databases.
- **StackGres Operator** in `stackgres` namespace, for automatic provisioning of dedicated PostgreSQL clusters.
- **KEDA**, for event-driven autoscaling of Frappe workers.
- **NGINX Ingress Controller**, pre-wired to the operator for HTTP/HTTPS routing to sites.
- **OpenEBS Dynamic NFS Provisioner**, exposing the `nfs-rwx-storage` StorageClass for ReadWriteMany (RWX) multi-replica benches.

No bench or site is created during install. You create your first bench after install.

## Databases

The operator supports MariaDB, PostgreSQL, and external databases. Both MariaDB and PostgreSQL operators are included:

| Engine | Mode | Provisioner |
|---|---|---|
| **MariaDB** (default) | shared or dedicated | MariaDB Operator (bundled subchart) |
| **PostgreSQL** | dedicated | StackGres Operator (installed in `stackgres`) |
| **PostgreSQL** | shared | DO Managed PostgreSQL (or any reachable `host:port`) |

### Example 1: FrappeBench with MariaDB (Default)

```yaml
apiVersion: vyogo.tech/v1
kind: FrappeBench
metadata:
  name: mariadb-bench
  namespace: default
spec:
  frappeVersion: "version-15"
  storageClassName: "nfs-rwx-storage"
  apps:
    - name: erpnext
      source: image
---
apiVersion: vyogo.tech/v1
kind: FrappeSite
metadata:
  name: site1-local
  namespace: default
spec:
  benchRef:
    name: mariadb-bench
  siteName: site1.local
  domain: site1.local
  dbConfig:
    provider: mariadb
    mode: shared
```

### Example 2: FrappeBench with PostgreSQL (StackGres)

```yaml
apiVersion: vyogo.tech/v1
kind: FrappeBench
metadata:
  name: postgres-bench
  namespace: default
spec:
  frappeVersion: "version-15"
  storageClassName: "nfs-rwx-storage"
  apps:
    - name: erpnext
      source: image
---
apiVersion: vyogo.tech/v1
kind: FrappeSite
metadata:
  name: site2-local
  namespace: default
spec:
  benchRef:
    name: postgres-bench
  siteName: site2.local
  domain: site2.local
  dbConfig:
    provider: postgres
    mode: dedicated
    postgresEngine: stackgres
```

## Storage (ReadWriteMany / RWX)

DigitalOcean's default block storage (`do-block-storage`) is ReadWriteOnce (RWO). For multi-replica benches, specify:

```yaml
spec:
  storageClassName: nfs-rwx-storage
```

This uses the bundled OpenEBS dynamic NFS provisioner to create RWX volumes backed by DO block storage.

## Installation

Run `deploy.sh`, which is equivalent to:

```bash
helm repo add frappe-operator https://vyogotech.github.io/frappe-operator/helm-repo
helm repo update

helm upgrade frappe-operator frappe-operator/frappe-operator \
  --atomic \
  --create-namespace \
  --install \
  --timeout 8m0s \
  --namespace frappe-operator-system \
  --values values.yml
```

Verify:

```bash
kubectl get pods -n frappe-operator-system
kubectl get pods -n stackgres
kubectl get storageclass
```

## Upgrading and uninstalling

Run `upgrade.sh` to move to a newer chart version, and `uninstall.sh` to remove the
release. Database data and CRDs are preserved on uninstall.

## License and support

The Frappe Operator is licensed under the [Elastic License 2.0](https://github.com/vyogotech/frappe-operator/blob/release/LICENSE).
Support: support@vyogo.tech
