# Part 3: K3d and Argo CD

## Overview

This part sets up a K3d Kubernetes cluster with Argo CD for continuous deployment of applications from a GitHub repository.

## What Gets Deployed

- **K3d Cluster**: A lightweight Kubernetes cluster running in Docker
- **Argo CD**: GitOps continuous deployment tool
- **Playground Application**: A simple application managed by Argo CD

## How to Run

### 1. Launch the Virtual Machine

```bash
cd P3
vagrant up
```

**This will take 5-10 minutes.** It will:

- Create a Debian Bookworm virtual machine
- Install Docker, kubectl, and K3d
- Create a K3d cluster named "inception"
- Install Argo CD (this can take a few minutes)
- Deploy the playground application from GitHub

Once the `vagrant up` command completes, everything is ready to use.

### 2. Access the Cluster

```bash
vagrant ssh K3d
```

### 3. Verify Everything is Running

```bash
cd /home/vagrant
bash scripts/test.sh
```

This checks:

- Cluster status
- Namespaces (argocd and dev)
- Argo CD deployment status
- Application deployment status

## Testing the Application

### Port Forward to the Application

```bash
kubectl port-forward svc/playground -n dev 8888:8888
```

Then test:

```bash
curl http://localhost:8888/
```

You should see:

```json
{ "status": "ok", "message": "v1" }
```

## Accessing Argo CD UI

### Port Forward Argo CD

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

### Open in Browser

Visit: `https://localhost:8080`

**Credentials:**

- Username: `admin`
- Password: (get from test.sh output)

## Changing Application Version

### 1. Edit the deployment.yaml in your GitHub repository

Change the image tag from `v1` to `v2`:

```yaml
image: wil42/playground:v2
```

### 2. Push to GitHub

```bash
git add P3/confs/deployment.yaml
git commit -m "Update app to v2"
git push origin main
```

### 3. Argo CD Will Automatically Sync

Check in Argo CD UI that it detected the change and applied it.

### 4. Verify New Version is Running

```bash
kubectl port-forward svc/playground -n dev 8888:8888
curl http://localhost:8888/
```

You should see:

```json
{ "status": "ok", "message": "v2" }
```

## File Structure

- `vagrantfile` - VM configuration
- `scripts/`
  - `install.sh` - Installs Docker, kubectl, K3d
  - `setup-argocd.sh` - Sets up Argo CD and creates namespaces
  - `test.sh` - Verification script
- `confs/`
  - `deployment.yaml` - Kubernetes deployment for the application
  - `dev-namespace.yaml` - Dev namespace definition
  - `argocd-application.yaml` - Argo CD application definition

## Troubleshooting

### Installation takes a long time

This is normal. K3d cluster creation and Argo CD installation can take 5-10 minutes total. Check the Vagrant output for progress.

### "metadata.annotations: Too long" error during vagrant up

This is a known issue with Argo CD's manifest. The setup script handles this automatically by downloading the manifest locally before applying it. Just wait for vagrant up to complete.

### Cluster not ready

Wait a few minutes for K3d and Argo CD to fully start.

If the process seems stuck, you can SSH in and check:

```bash
vagrant ssh K3d
kubectl get nodes
kubectl get pods -n argocd
```

### Pods not deploying

Check Argo CD Application status in the UI or:

```bash
kubectl describe application inception-app -n argocd
```

Also check that the GitHub repository URL is correct in the Application manifest.

### Can't access application

Ensure port-forward is running and the pod is in Running state:

```bash
kubectl get pods -n dev
```

If pods are still creating, wait a bit longer. If pods are in Error/CrashLoopBackOff, check the logs:

```bash
kubectl logs -n dev deployment/playground
```

### Argo CD UI shows "OutOfSync"

This is normal initially. Argo CD automatically syncs within a few minutes. You can manually trigger a sync in the UI or:

```bash
kubectl patch application inception-app -n argocd -p '{"metadata":{"annotations":{"argocd.argoproj.io/compare-result":""}}}' --type merge
```
