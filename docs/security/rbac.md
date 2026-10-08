# RBAC — Phase 13

**Evidence Classification:** LOCALLY VALIDATED  
**Cluster:** `db-platform-tf` (kind, Kubernetes v1.33.1)

---

## ServicePulse Service Account Audit

### Current Posture

ServicePulse runs using the `default` ServiceAccount in the `servicepulse` namespace.

```
$ kubectl get pod servicepulse-65f6867bf8-kvfr9 -n servicepulse \
    -o jsonpath='{.spec.serviceAccountName}'
default
```

The `default` SA in a namespace with no custom RBAC bindings holds only the minimal permissions granted to all service accounts (self-subject review, OIDC discovery, API discovery).

```
$ kubectl auth can-i --as=system:serviceaccount:servicepulse:default --list -n servicepulse
Resources                                       Verbs
selfsubjectreviews.authentication.k8s.io        [create]
selfsubjectaccessreviews.authorization.k8s.io   [create]
selfsubjectrulesreviews.authorization.k8s.io    [create]
(non-resource URLs for OIDC/healthz/version)
```

ServicePulse has **no `get`, `list`, or `watch` permissions** on pods, secrets, deployments, or any other resource. **LOCALLY VALIDATED.**

### Gap: automountServiceAccountToken

The default SA token is automatically mounted by Kubernetes (`automountServiceAccountToken` defaults to `true` at the namespace level). ServicePulse does not use the Kubernetes API and therefore does not need this token.

The running pod has a projected `kube-api-access-8527s` volume mounted at `/var/run/secrets/kubernetes.io/serviceaccount`. This is the default auto-mount behaviour.

**Remediation (implemented in Helm chart values):**
`automountServiceAccountToken: false` added to the chart ServiceAccount template.

See `charts/servicepulse/values.yaml` — `serviceAccount.automount: false`.

---

## Least-Privilege RBAC Demonstration

### Identity: `platform-reader`

Created in `servicepulse` namespace. Manifest: `k8s/rbac/platform-reader.yaml`.

```yaml
ServiceAccount:
  name: platform-reader
  namespace: servicepulse
  automountServiceAccountToken: false

Role: servicepulse-pod-reader
  rules:
    - apiGroups: [""]
      resources: ["pods"]
      verbs: ["get", "list", "watch"]
    - apiGroups: [""]
      resources: ["endpoints"]
      verbs: ["get", "list"]
```

### RBAC Validation Evidence

```
$ READER="system:serviceaccount:servicepulse:platform-reader"
```

**ALLOWED — get pods in servicepulse namespace:**
```
$ kubectl auth can-i get pods --as="${READER}" -n servicepulse
yes
```

**ALLOWED — list endpoints in servicepulse namespace:**
```
$ kubectl auth can-i list endpoints --as="${READER}" -n servicepulse
yes
```

**DENIED — list secrets cluster-wide:**
```
$ kubectl auth can-i list secrets --as="${READER}"
no
```

**DENIED — delete deployments:**
```
$ kubectl auth can-i delete deployments --as="${READER}" -n servicepulse
no
```

**DENIED — access monitoring namespace:**
```
$ kubectl auth can-i get pods --as="${READER}" -n monitoring
no
```

**DENIED — modify services:**
```
$ kubectl auth can-i update services --as="${READER}" -n servicepulse
no
```

**Evidence classification: LOCALLY VALIDATED.**

---

## Default ServiceAccount Negative Checks

```
$ kubectl auth can-i list secrets \
    --as=system:serviceaccount:servicepulse:default
no

$ kubectl auth can-i delete pods \
    --as=system:serviceaccount:servicepulse:default -n servicepulse
no
```

**LOCALLY VALIDATED.**

---

## Principles Demonstrated

| Principle | Evidence |
|---|---|
| Least privilege | `platform-reader` has only what operations require |
| Namespace isolation | `platform-reader` cannot access `monitoring` namespace |
| No cluster-admin | Neither SA has cluster-wide write access |
| No unnecessary API access | ServicePulse `default` SA has no application-level permissions |
| Token minimization | `platform-reader` sets `automountServiceAccountToken: false` |

---

## What This Is NOT

- No `cluster-admin` binding was created
- No ClusterRole with wildcard verbs
- No production IAM/OIDC federation
- No admission webhooks for RBAC enforcement
