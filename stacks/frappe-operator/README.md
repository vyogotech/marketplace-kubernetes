# Frappe Operator 1-Click for DigitalOcean Kubernetes

Installs the [Frappe Operator](https://github.com/vyogotech/frappe-operator) on a
DigitalOcean Kubernetes cluster. The operator turns Frappe and ERPNext into
declarative Kubernetes resources: you describe a bench and its sites as YAML, and
the operator provisions databases, runs migrations, takes backups and installs
apps for you.

It manages 24 custom resources, including `FrappeBench`, `FrappeSite`,
`SiteMigration`, `SiteBackup`, `SiteRestore` and `SiteApp`.

If you want PostgreSQL instead of MariaDB, use the **Frappe Operator with
PostgreSQL** listing. Install one or the other, not both — they install the same
Helm release name into the same namespace.

## Prerequisites

1. **Helm 3** on your local machine.
2. **A DigitalOcean Kubernetes cluster**, with your kubeconfig configured to reach it.
3. **At least one node with 2 GB of RAM.** The operator itself requests only
   100m CPU / 128Mi, but it installs MariaDB Operator and KEDA alongside it.

## What gets installed

- The Frappe Operator control plane in the `frappe-operator-system` namespace.
- 24 CRDs.
- MariaDB Operator, for provisioning per-site databases.
- KEDA, for autoscaling Frappe workers.

No bench or site is created. You create your first bench after install.

## Companion 1-Click apps

Neither is installed by this app, because both already exist as DigitalOcean
1-Click apps you can select alongside it when creating the cluster, or add later.

**NGINX Ingress Controller.** DOKS ships no ingress controller, so a `FrappeSite`
has no external route until one exists. The operator's defaults already match
what that 1-Click installs — service `ingress-nginx-controller` in namespace
`ingress-nginx` — so no configuration is needed. It provisions a DigitalOcean
Load Balancer, which is billed separately.

**OpenEBS NFS Provisioner.** Only needed for multi-node benches; see Storage.

## Databases

The operator supports four database providers. Only the default needs anything
installed by this 1-click.

| Provider | Mode | What it needs | Installed by this 1-click |
|---|---|---|---|
| `mariadb` (default) | shared or dedicated | MariaDB Operator | **Yes**, bundled as a subchart |
| `postgres` | shared | a reachable `host:port` | No operator required |
| `postgres` | dedicated | StackGres **or** Percona operator | No — install it yourself |
| `external` | — | `host` and a connection secret | Nothing in-cluster |

### The default: in-cluster MariaDB

Nothing to do. MariaDB Operator is installed alongside the Frappe Operator and
provisions a database per site. DigitalOcean does not offer a managed MariaDB, so
in-cluster is the path for MariaDB.

### Managed PostgreSQL

Shared-mode PostgreSQL is engine-agnostic — it needs only a reachable host and
port, no in-cluster database operator. That makes a [DigitalOcean Managed
PostgreSQL](https://www.digitalocean.com/products/managed-databases-postgresql)
cluster a drop-in backing store, with backups, failover and patching handled for
you and no database PVCs in your cluster:

```yaml
apiVersion: vyogo.tech/v1
kind: FrappeBench
metadata:
  name: example-bench
spec:
  frappeVersion: "version-15"
  dbConfig:
    provider: postgres
    mode: shared
    host: your-cluster-do-user-000000.b.db.ondigitalocean.com
    port: "25060"
    connectionSecretRef:
      name: managed-pg-credentials
  apps:
    - name: erpnext
      source: image
```

If you go this route you can turn the bundled MariaDB Operator off entirely:

```bash
helm upgrade ... --set mariadb-operator.enabled=false
```

### Dedicated PostgreSQL clusters

`dbConfig.mode: dedicated` with `postgresEngine: stackgres` or `percona` gives each
site its own PostgreSQL cluster. **Install the corresponding operator first** —
the Frappe Operator creates `SGCluster` or `PerconaPGCluster` resources and cannot
provision them if those CRDs are absent.

## Storage

`storageClassName` is left empty, so a bench uses the cluster default —
`do-block-storage` on DOKS, which is `ReadWriteOnce` only. The operator detects
this and provisions bench volumes as RWO, which schedules a bench's pods onto a
single node.

For multi-node benches you need a `ReadWriteMany` class. DigitalOcean ships one
as a 1-Click app, **OpenEBS NFS Provisioner**, which layers an NFS server over
`do-block-storage` and creates a StorageClass named `nfs-rwx-storage`. Install it
alongside this app, then name the class on your bench — the operator will not
pick it up on its own, because it is not the cluster default:

```yaml
spec:
  storageClassName: nfs-rwx-storage
```

The operator recognises its `openebs.io/nfsrwx` provisioner as RWX-capable and
provisions the bench volume accordingly.

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
  --values values.yml \
  --version 5.2.0
```

Verify:

```bash
kubectl get pods -n frappe-operator-system
kubectl get crds | grep vyogo.tech
```

## Creating your first bench

```yaml
apiVersion: vyogo.tech/v1
kind: FrappeBench
metadata:
  name: example-bench
  namespace: default
spec:
  frappeVersion: "version-15"
  apps:
    - name: erpnext
      source: image
```

## Upgrading and uninstalling

Run `upgrade.sh` to move to a newer chart version, and `uninstall.sh` to remove the
release. Uninstalling does not delete the CRDs or any benches and sites you
created; remove those first if you want a clean teardown.

## Licence and support

The Frappe Operator is licensed under the [Elastic License 2.0](https://github.com/vyogotech/frappe-operator/blob/release/LICENSE).
Support: support@vyogo.tech
