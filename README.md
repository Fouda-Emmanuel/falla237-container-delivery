# Falla237 Container Delivery Pipeline

A production-ready CI/CD pipeline that automates the build, security scanning, and delivery of containerized Django applications. The pipeline implements a clean separation between validation, development, and release stages, ensuring predictable and controlled deployments.

---

## Overview

This project demonstrates a complete container delivery workflow for a Django application. It combines secure Docker image building, multi-stage optimization, automated security scanning, and multi-registry publishing. The pipeline is triggered by different GitHub events (PR, push to main, version tags) and follows a structured approach where each stage has a clear responsibility.

---

## CI/CD Pipeline Flow

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                    Falla237 Container Delivery CI Pipeline                          │
│                        GitHub Actions Workflow                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘

                                         │
                    ┌────────────────────┼────────────────────┐
                    │                    │                    │
                 [PR Event]         [Push Event]         [Tag Event]
               (pull_request)      (push to main)        (tags: v*)
                    │                    │                    │
                    └────────────────────┼────────────────────┘
                                         │
                                         ▼
                    ┌────────────────────────────────────────┐
                    │           JOB: build_and_scan          │
                    │          (Runs for ALL events)         │
                    └────────────────────────────────────────┘
                                         │
                    ┌────────────────────────────────────────┐
                    │  Step: Checkout Code                   │
                    │  Step: Setup Docker Buildx             │
                    │  Step: Build Docker Image              │
                    │  Step: Scan with Trivy                 │
                    │  Step: Upload Trivy Report             │
                    └────────────────────────────────────────┘
                                         │
                    ┌────────────────────┼────────────────────┐
                    │                    │                    │
                    ▼                    ▼                    ▼
            ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
            │  PR Event    │    │  Push Event  │    │  Tag Event   │
            │  (PR Only)   │    │  (main)      │    │  (v*)        │
            └──────────────┘    └──────────────┘    └──────────────┘
                    │                    │                    │
                    │              ┌─────┴─────┐              │
                    │              │           │              │
                    │              ▼           ▼              ▼
                    │    ┌─────────────────────────────────────────┐
                    │    │      JOB: publish (Conditional)         │
                    │    │      if: github.event_name != 'PR'      │
                    │    └─────────────────────────────────────────┘
                    │              │           │              │
                    │              ▼           ▼              ▼
                    │    ┌─────────────────────────────────────────┐
                    │    │          Detect Pipeline Type:          │
                    │    │          - Push → DEV pipeline          │
                    │    │          - Tag  → RELEASE pipeline      │
                    │    └─────────────────────────────────────────┘
                    │              │           │              │
                    │              ▼           ▼              ▼
                    │    ┌─────────────────────────────────────────┐
                    │    │         Configure AWS Credentials       │
                    │    │         Login to Amazon ECR             │
                    │    │         Login to Docker Hub             │
                    │    └─────────────────────────────────────────┘
                    │              │           │              │
                    │              ▼           ▼              ▼
                    │    ┌─────────────────────────────────────────┐
                    │    │           Build Docker Image            │
                    │    │           Tag Images:                   │
                    │    │           - :latest                     │
                    │    │           - :sha-{commit}               │
                    │    │           - :{version} (RELEASE only)   │
                    │    └─────────────────────────────────────────┘
                    │              │           │              │
                    │              ▼           ▼              ▼
                    │    ┌─────────────────────────────────────────┐
                    │    │              Push Images:               │
                    │    │              → Docker Hub               │
                    │    │              → Amazon ECR               │
                    │    └─────────────────────────────────────────┘
                    │              │           │              │
                    ▼              ▼           ▼              ▼
            ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
            │  PR Flow     │ │  Push Flow   │ │  Tag Flow    │
            │  Ends Here   │ │  DEV Build   │ │  RELEASE     │
            │              │ │  Published   │ │  Published   │
            │ ✓ Validation │ │ ✓ :latest    │ │ ✓ :latest    │
            │   Complete   │ │ ✓ :sha-*     │ │ ✓ :sha-*     │
            └──────────────┘ │              │ │ ✓ :{version} │
                             └──────────────┘ └──────────────┘
```

---

## Pipeline Stages

### 1. Pull Request Pipeline (Validation Only)
**Trigger:** PR opened to `main`

| Step | Action |
|------|--------|
| Build | Docker image built using GitHub Actions cache |
| Scan | Trivy scans for HIGH/CRITICAL vulnerabilities |
| Report | Scan results uploaded as artifact |
| Push | **No image is pushed** to registries |

**Goal:** Fast validation without unnecessary registry pushes.

---

### 2. Development Pipeline
**Trigger:** Push/merge to `main`

| Step | Action |
|------|--------|
| Build | Rebuild image (reuses cached layers) |
| Tag | `latest` and `sha-<commit>` |
| Push | Docker Hub + AWS ECR |

**Goal:** Every change on main is immediately deployable.

---

### 3. Release Pipeline
**Trigger:** Git tag starting with `v` (e.g., `v1.0.0`)

| Step | Action |
|------|--------|
| Build | Same as development pipeline |
| Tag | `latest`, `sha-<commit>`, and semantic version (e.g., `v1.0.0`) |
| Push | Docker Hub + AWS ECR |

**Goal:** Create traceable, versioned artifacts for production deployments.


---

## Docker Implementation

### Multi-Stage Dockerfile

The Dockerfile uses a **multi-stage build** approach to create a lean, secure production image:

| Stage | Purpose |
|-------|---------|
| **Builder** | Installs build dependencies, compiles requirements, and prepares the application |
| **Runtime** | Creates a minimal production image with only runtime dependencies and the built application |

**Key design decisions:**
- **Security**: Uses a non-root user (`django-user`) for runtime
- **Efficiency**: Only copies necessary artifacts from builder stage
- **Database readiness**: Includes `libpq5` for PostgreSQL connectivity
- **Static files**: Creates dedicated directories for static and media files

### Entrypoint Script

The `entrypoint.sh` script ensures the application starts reliably by implementing:

| Feature | Purpose |
|---------|---------|
| **Database availability check** | Waits for the database to be ready before starting the application |
| **Timeout mechanism** | 2-minute hard timeout with warning at 30 seconds |
| **Static file collection** | Runs `collectstatic` automatically on startup |
| **Error handling** | Uses `set -o errexit` to fail on any error |

This approach makes the container self-sufficient and ready for any environment—whether running locally, on AWS, or on platforms like Render.

---

## Technologies Used

| Category | Technologies |
|----------|--------------|
| **CI/CD** | GitHub Actions |
| **Containerization** | Docker (multi-stage builds) |
| **Security Scanning** | Trivy |
| **Registries** | Docker Hub, AWS ECR |
| **Application** | Python / Django |
| **Infrastructure** | AWS (via configured credentials) |

---

## Security & Best Practices

| Practice | Implementation |
|----------|----------------|
| **Non-root user** | Runtime runs as `django-user` |
| **Multi-stage builds** | Minimal production image, build dependencies excluded |
| **Security scanning** | Trivy scans on every PR (HIGH/CRITICAL vulnerabilities) |
| **Secrets management** | All credentials stored as GitHub Secrets |
| **Caching** | Docker layer caching for faster builds |
| **Database readiness** | Entrypoint script waits for DB before starting |

---

## Image Tagging Strategy

| Tag | Purpose | Applied In |
|-----|---------|------------|
| `latest` | Always points to the most recent build | DEV + RELEASE |
| `sha-<commit>` | Traceable to specific commit | DEV + RELEASE |
| `v1.0.0` | Semantic version for releases | RELEASE only |

---

## Deployment Readiness

This pipeline is designed to integrate seamlessly with:

- **AWS ECS** – Use the pushed ECR images directly
- **AWS EKS** – Pull images from ECR for Kubernetes deployments
- **Render / Heroku** – Pull images from Docker Hub

The entrypoint script's database health check ensures smooth startup across any platform that provides a `DATABASE_URL` environment variable.

---

## Environment Configuration

| Type | Variable | Purpose |
|------|----------|---------|
| **Secret** | `AWS_ACCESS_KEY_ID` | AWS authentication for ECR |
| **Secret** | `AWS_SECRET_ACCESS_KEY` | AWS authentication for ECR |
| **Secret** | `DOCKERHUB_USERNAME` | Docker Hub authentication |
| **Secret** | `DOCKERHUB_TOKEN` | Docker Hub authentication |
| **Variable** | `IMAGE_NAME` | Base name for Docker images |
| **Variable** | `AWS_REGION` | AWS region for ECR |
| **Variable** | `ECR_REGISTRY` | AWS ECR registry URL |
| **Variable** | `ECR_REPOSITORY` | AWS ECR repository name |

---

## Key Achievements

- **Clean separation** between validation, development, and release stages
- **Security-first approach** with automated vulnerability scanning before any image is pushed
- **Efficient builds** using Docker layer caching across jobs
- **Consistent tagging** enabling traceability from commit to production
- **Multi-registry support** for flexibility across different deployment targets

---

*This project demonstrates production-ready CI/CD practices for containerized applications, with a focus on security, efficiency, and predictable delivery.*
