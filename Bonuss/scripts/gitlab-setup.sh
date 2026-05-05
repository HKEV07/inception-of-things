#!/bin/bash
# bonus/scripts/gitlab-setup.sh
set -e

export KUBECONFIG=/home/vagrant/.kube/config

GITLAB_IP="192.168.56.110"
GITLAB_PORT="30080"
GITLAB_URL="http://${GITLAB_IP}:${GITLAB_PORT}"
GITLAB_USER="root"

# Get the GitLab root password from the secret
GITLAB_PASS=$(kubectl -n gitlab get secret gitlab-gitlab-initial-root-password \
  -o jsonpath='{.data.password}' | base64 --decode)

echo "GitLab URL : $GITLAB_URL"
echo "GitLab pass: $GITLAB_PASS"

# ── 1. Get a personal access token via API ────────────────────────────────────
echo "=== Creating GitLab API token ==="
TOKEN_RESPONSE=$(curl -s --request POST "${GITLAB_URL}/api/v4/users/1/personal_access_tokens" \
  --header "Content-Type: application/json" \
  --user "${GITLAB_USER}:${GITLAB_PASS}" \
  --data '{
    "name": "argocd-token",
    "scopes": ["api", "read_repository", "write_repository"],
    "expires_at": "2099-01-01"
  }')

GITLAB_TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
echo "Token created: ${GITLAB_TOKEN:0:8}..."

# ── 2. Create the project (repo) ─────────────────────────────────────────────
echo "=== Creating GitLab project ==="
curl -s --request POST "${GITLAB_URL}/api/v4/projects" \
  --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  --header "Content-Type: application/json" \
  --data '{
    "name": "iot",
    "visibility": "public",
    "initialize_with_readme": true
  }'

# ── 3. Push manifests to GitLab ───────────────────────────────────────────────
echo "=== Pushing manifests to GitLab ==="

TMPDIR=$(mktemp -d)
cd "$TMPDIR"

git init
git config user.email "vagrant@iot.local"
git config user.name "vagrant"

# Copy the confs
cp /vagrant/confs/deployment.yaml .
cp /vagrant/confs/service.yaml .


git add .
git commit -m "initial manifests"

# Push using the token for authentication
git remote add origin \
  "http://root:${GITLAB_TOKEN}@${GITLAB_IP}:${GITLAB_PORT}/root/iot.git"
git push -u origin main 2>/dev/null || git push -u origin master

cd /
rm -rf "$TMPDIR"

# ── 4. Add GitLab repo credentials to Argo CD ────────────────────────────────
echo "=== Adding GitLab credentials to Argo CD ==="
kubectl create secret generic gitlab-repo-creds \
  -n argocd \
  --from-literal=type=git \
  --from-literal=url=http://gitlab-webservice-default.gitlab.svc.cluster.local:8181/root/iot.git \
  --from-literal=username=root \
  --from-literal=password="${GITLAB_TOKEN}" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl label secret gitlab-repo-creds -n argocd \
  argocd.argoproj.io/secret-type=repository --overwrite

# ── 5. Apply the Argo CD Application ─────────────────────────────────────────
echo "=== Applying Argo CD Application ==="
kubectl apply -f /vagrant/confs/application.yaml

echo ""
echo "========================================="
echo " GitLab UI : http://192.168.56.110:30080"
echo " Username  : root"
echo " Password  : $GITLAB_PASS"
echo " Repo      : http://192.168.56.110:30080/root/iot"
echo ""
echo " Argo CD   : https://192.168.56.110:8080 (after port-forward)"
echo "========================================="
echo ""
echo "Watch sync: kubectl get application wil-playground -n argocd -w"