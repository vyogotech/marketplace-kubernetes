# Frappe Operator with PostgreSQL — 1-Click for DigitalOcean Kubernetes

Installs the [Frappe Operator](https://github.com/vyogotech/frappe-operator) backed
by **PostgreSQL** instead of MariaDB, together with the StackGres PostgreSQL
Operator that provisions the clusters.

If you want the MariaDB default instead, use the **Frappe Operator** listing.
Install one or the other, not both — they install the same Helm release name into
the same namespace.

## Which listing should I use?

| | Frappe Operator | Frappe Operator with PostgreSQL |
|---|---|---|
| Database | MariaDB, in-cluster | PostgreSQL, in-cluster |
| Provisioned by | MariaDB Operator (bundled) | StackGres Operator (installed by `deploy.sh`) |
| Frappe support | Primary, best tested | Supported |
| Use when | You want the default Frappe stack | Your team standardises on PostgreSQL |

There is a third option neither listing covers: point Frappe at a **DigitalOcean
Managed PostgreSQL** cluster. Shared-mode PostgreSQL needs only a reachable host
and port — no in-cluster database operator at all. Install the MariaDB listing
with `--set mariadb-operator.enabled=false`, or this one, and set `host` in your
bench's `dbConfig`. That gives you managed backups and failover with no database
PVCs in the cluster.

## Prerequisites

1. **Helm 3** on your local machine.
2. **A DigitalOcean Kubernetes cluster**, kubeconfig configured.
3. **At least 4 GB of RAM across your nodes.** StackGres runs several components
   alongside the Frappe Operator and KEDA — more than the MariaDB listing needs.

## What gets installed

- StackGres PostgreSQL Operator, in namespace `stackgres`.
- The Frappe Operator control plane in `frappe-operator-system`.
- 24 CRDs.
- KEDA, for worker autoscaling.
- **No MariaDB Operator.**

No bench or site is created.

## Creating a PostgreSQL-backed bench

The database provider is chosen per bench, not chart-wide:

```yaml
apiVersion: vyogo.tech/v1
kind: FrappeBench
metadata:
  name: example-bench
  namespace: default
spec:
  frappeVersion: "version-15"
  dbConfig:
    provider: postgres
    mode: dedicated
    postgresEngine: stackgres
  apps:
    - name: erpnext
      source: image
```

`mode: dedicated` gives each site its own PostgreSQL cluster. For one shared
instance across sites, use `mode: shared` with a `host` — that path is
engine-agnostic and works against DigitalOcean Managed PostgreSQL.

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

StackGres provisions its own volumes per cluster and is unaffected.

## Companion 1-Click apps

Neither is installed by this app, because both already exist as DigitalOcean
1-Click apps you can select alongside it when creating the cluster, or add later.

**NGINX Ingress Controller.** DOKS ships no ingress controller, so a `FrappeSite`
has no external route until one exists. The operator's defaults already match
what that 1-Click installs — service `ingress-nginx-controller` in namespace
`ingress-nginx` — so no configuration is needed. It provisions a DigitalOcean
Load Balancer, which is billed separately.

**OpenEBS NFS Provisioner.** Only needed for multi-node benches; see Storage.

## Uninstalling

`uninstall.sh` removes the Frappe Operator release. **It deliberately leaves
StackGres installed**, because removing it would delete the `SGCluster` resources
holding your site databases. Once you have confirmed nothing depends on it:

```bash
kubectl get sgclusters -A
helm uninstall stackgres-operator -n stackgres
```

## Licence and support

Elastic License 2.0. Support: support@vyogo.tech
