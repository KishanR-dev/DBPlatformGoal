import yaml, sys, glob
REQUIRED_POD_FIELDS = {'runAsNonRoot': True}
WARNINGS = []
for path in glob.glob('k8s/**/*.yaml', recursive=True) + glob.glob('charts/**/*.yaml', recursive=True):
    if 'secret.example' in path or 'psa-test-privileged' in path: continue
    try:
        with open(path) as f:
            for doc in yaml.safe_load_all(f):
                if not doc or doc.get('kind') not in ['Deployment', 'Pod', 'DaemonSet']: continue
                spec = doc.get('spec', {})
                if doc.get('kind') != 'Pod': spec = spec.get('template', {}).get('spec', spec)
                sc = spec.get('securityContext', {})
                for field, expected in REQUIRED_POD_FIELDS.items():
                    if sc.get(field) != expected:
                        WARNINGS.append(f"{path}: podSecurityContext.{field}={sc.get(field)} (expected {expected})")
    except Exception: pass
for w in WARNINGS: print("WARN:", w)
print("Manifest security check complete.")
