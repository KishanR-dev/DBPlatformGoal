#!/bin/bash
set -euo pipefail

# DBPlatformGoal Local GitLab CI Mock Execution
# Emulates a GitLab CI Runner locally without modifying the host ecosystem.
# Python jobs bypass WSL host 'Python 3.14' friction by utilizing the exact
# 'python:3.12-slim' target defined in .gitlab-ci.yml via ephemeral docker contexts.

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}========================================================================${NC}"
echo -e "${BLUE}  Starting DBPlatformGoal Local CI Pipeline Simulation                  ${NC}"
echo -e "${BLUE}========================================================================${NC}"

export PYTHON_VERSION="3.12"
export IMAGE_REPOSITORY="dbplatform/servicepulse"
export KUBE_NAMESPACE="servicepulse"
export HELM_RELEASE="servicepulse"
export CI_COMMIT_SHORT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "local")
export IMAGE_TAG="git-${CI_COMMIT_SHORT_SHA}"

run_stage() {
    echo -e "\n${BLUE}--- Stage: $1 ---${NC}"
}

run_job_host() {
    local job_name=$1
    shift 1
    echo -e "${GREEN}[JOB] ${job_name} (executor: host shell)${NC}"
    eval "$@"
    echo -e "${GREEN}✓ ${job_name} SUCCESS${NC}"
}

# -----------------------------------------------------------------------------
# 0. EMULATOR CONTEXT SETUP
# -----------------------------------------------------------------------------
echo -e "${BLUE}Building Ephemeral CI Context (python:${PYTHON_VERSION}-slim) to prevent WSL mount issues...${NC}"
# We build an image that statically copies the repository at current commit,
# mimicking what a runner does when it clones the repo before starting a job.
docker build -t dbplatformgoal-ci-emulator -f - . <<EOF
FROM python:${PYTHON_VERSION}-slim
WORKDIR /builds/dbplatformgoal
COPY . /builds/dbplatformgoal
# Install dependencies up front to speed up mock stage execution
RUN pip install --no-cache-dir ruff==0.9.9 bandit==1.7.7
RUN cd src/servicepulse && pip install --no-cache-dir -r requirements.txt -r requirements-dev.txt
EOF

# -----------------------------------------------------------------------------
# 1. STAGE: VALIDATE
# -----------------------------------------------------------------------------
run_stage "validate"

echo -e "${GREEN}[JOB] lint:python${NC}"
docker run --rm dbplatformgoal-ci-emulator bash -c "
set -euo pipefail
cd src/servicepulse
ruff check app tests
"
echo -e "${GREEN}✓ lint:python SUCCESS${NC}"

echo -e "${GREEN}[JOB] lint:helm${NC}"
# Helm lint doesn't strictly need volume writeback, so we can just run via a static docker build
# OR execute natively since helm v3 is already locally verified on the host
run_job_host "lint:helm" "
helm lint charts/servicepulse
helm template servicepulse charts/servicepulse -f charts/servicepulse/values-dev.yaml > /dev/null
"

# -----------------------------------------------------------------------------
# 2. STAGE: TEST
# -----------------------------------------------------------------------------
run_stage "test"

echo -e "${GREEN}[JOB] test:unit${NC}"
docker run --rm dbplatformgoal-ci-emulator bash -c "
set -euo pipefail
cd src/servicepulse
pytest --cov=app --cov-report=xml --cov-fail-under=85
"
echo -e "${GREEN}✓ test:unit SUCCESS${NC}"

# -----------------------------------------------------------------------------
# 3. STAGE: SECURITY
# -----------------------------------------------------------------------------
run_stage "security"

echo -e "${GREEN}[JOB] security:bandit${NC}"
docker run --rm dbplatformgoal-ci-emulator bash -c "
set -euo pipefail
cd src/servicepulse
bandit -r app -ll
"
echo -e "${GREEN}✓ security:bandit SUCCESS${NC}"

# -----------------------------------------------------------------------------
# 4. STAGE: BUILD
# -----------------------------------------------------------------------------
run_stage "build"

run_job_host "build:container" "
cd container/servicepulse
docker build -t \${IMAGE_REPOSITORY}:\${IMAGE_TAG} -f Dockerfile ../../src/servicepulse
docker save \${IMAGE_REPOSITORY}:\${IMAGE_TAG} > servicepulse-image.tar
cd ../..
"

# -----------------------------------------------------------------------------
# 5. STAGE: PACKAGE
# -----------------------------------------------------------------------------
run_stage "package"

run_job_host "package:helm" "
mkdir -p charts/dist
helm package charts/servicepulse -d charts/dist
"

# -----------------------------------------------------------------------------
# 6. STAGE: DEPLOY
# -----------------------------------------------------------------------------
run_stage "deploy"

run_job_host "deploy:kind" "
cd container/servicepulse
docker load -i servicepulse-image.tar
kind load docker-image \${IMAGE_REPOSITORY}:\${IMAGE_TAG} --name db-platform
cd ../..
helm upgrade --install \${HELM_RELEASE} charts/servicepulse \
    --namespace \${KUBE_NAMESPACE} --create-namespace \
    -f charts/servicepulse/values-dev.yaml \
    --set image.repository=\${IMAGE_REPOSITORY} \
    --set image.tag=\${IMAGE_TAG}
"

# -----------------------------------------------------------------------------
# 7. STAGE: VERIFY
# -----------------------------------------------------------------------------
run_stage "verify"

run_job_host "verify:health" "
kubectl rollout status deployment/\${HELM_RELEASE} -n \${KUBE_NAMESPACE} --timeout=120s
kubectl -n \${KUBE_NAMESPACE} run ci-smoke-test-health --image=curlimages/curl:latest --restart=Never --rm -i -- -s --fail http://\${HELM_RELEASE}/health
kubectl -n \${KUBE_NAMESPACE} run ci-smoke-test-metrics --image=curlimages/curl:latest --restart=Never --rm -i -- -s --fail http://\${HELM_RELEASE}/api/v1/metrics
"

echo -e "\n${BLUE}========================================================================${NC}"
echo -e "${BLUE}  Local Pipeline Simulation Completed Successfully                      ${NC}"
echo -e "${BLUE}========================================================================${NC}"
