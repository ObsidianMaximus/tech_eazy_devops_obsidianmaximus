# Tech Eazy DevOps: One-Click AWS Spring Boot Deployment

Welcome to **Tech Eazy DevOps** — the fastest way to build, deploy, and auto-manage your Spring Boot application on AWS EC2 using GitHub Actions, SSM, and Lambda.

---

## What Makes This Awesome

- **Push-to-Deploy:** Deploy your app to the cloud with every code push. No manual steps.
- **Zero Touch:** Everything runs automatically—build, deploy, run, and auto-stop.
- **Cloud Native:** Uses AWS Systems Manager, EventBridge, and Lambda for secure, reliable ops.
- **Health Checked:** Verifies your app is running on port 80 before marking the deployment a success.
- **Auto Stop:** Never leave a dev instance running by accident—automatic shutdown after deployment.

---

## How the Flow Works

1. **Code Push or Manual Trigger**

   Push to `master` or trigger the deployment workflow in GitHub Actions. No cloud console needed.

2. **GitHub Workflow Launches**

   - Builds your Spring Boot app with Maven.
   - Packages and prepares it for deployment.

3. **EC2 Deployment via SSM**

   - Workflow finds your running EC2 instance.
   - Sends a deployment command via AWS SSM (secure, agent-based).
   - The EC2 runs `deploy.sh`, which:
     - Installs needed tools (Java, Maven).
     - Clones your latest code.
     - Builds and starts your Spring Boot app on port 80.
     - Verifies the app is reachable.

4. **Scheduled Auto-Termination**

   - After deployment, EventBridge schedules a Lambda function to auto-stop your EC2 instance after 20 minutes.
   - Your cloud stays clean—no wasted resources.

---

## Visual Flow

```
Push to GitHub
      │
      ▼
GitHub Actions Workflow
      │
      ▼
Build & Package App
      │
      ▼
Send SSM Command to EC2
      │
      ▼
Run deploy.sh on EC2
      │
      ▼
App Starts on Port 80
      │
      ▼
Health Check
      │
      ▼
EventBridge schedules Lambda
      │
      ▼
Lambda stops EC2 after 20 min
```

---

## Quick Start

1. Set up AWS credentials as GitHub secrets.
2. Launch an EC2 instance with SSM enabled.
3. Push your code to `master`, or trigger the workflow manually.
4. Watch your app deploy to the cloud—automatically.

---

## Key Files

- `deploy.sh` – The script for EC2 deployment.
- `.github/workflows/` – The GitHub Actions workflow.
- `README.md` – This file.

---

## Why Use Tech Eazy DevOps

- Fast: Deploy in minutes, not hours.
- Safe: No more forgotten EC2s burning cash.
- Modern: Native AWS automation, no legacy hacks.
- Efficient: Your code comes alive, instantly.

---

Made by [ObsidianMaximus](https://github.com/ObsidianMaximus)
