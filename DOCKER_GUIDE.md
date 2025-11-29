# Docker Deployment Guide for ShopiNow

This guide explains how to build, run, and update the ShopiNow application using Docker.

## 📋 Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Building Images](#building-images)
- [Running the Application](#running-the-application)
- [Updating the Application](#updating-the-application)
- [Database Management](#database-management)
- [Logs and Debugging](#logs-and-debugging)
- [Production Deployment](#production-deployment)

## Prerequisites

- Docker (version 20.10+)
- Docker Compose (version 2.0+)

**Install Docker:**
- Windows/Mac: [Docker Desktop](https://www.docker.com/products/docker-desktop)
- Linux: 
  ```bash
  curl -fsSL https://get.docker.com -o get-docker.sh
  sudo sh get-docker.sh
  ```

**Verify installation:**
```bash
docker --version
docker-compose --version
```

## Quick Start

### 1. Clone and Configure

```bash
# Navigate to project directory
cd /path/to/shopinow

# Create environment file
cp .env.example .env

# Edit .env with your values (optional for local dev)
nano .env
```

### 2. Build and Run

```bash
# Build and start all services
docker-compose up -d

# Check status
docker-compose ps
```

### 3. Access the Application

- **Frontend:** http://localhost
- **Backend API:** http://localhost:8080/api
- **Swagger UI:** http://localhost:8080/swagger-ui.html
- **PostgreSQL:** localhost:5432

### 4. Stop the Application

```bash
# Stop all services
docker-compose down

# Stop and remove volumes (WARNING: deletes database)
docker-compose down -v
```

## Configuration

### Environment Variables

Create a `.env` file in the project root:

```env
# Database
DB_PASSWORD=secure_password_here

# JWT Secret (256+ bits)
JWT_SECRET=your_256bit_secret_key_here

# CORS Origins
CORS_ALLOWED_ORIGINS=http://localhost,https://yourdomain.com
```

### Frontend API URL

Update `ShopiNow/src/environments/environment.ts`:

```typescript
export const environment = {
  production: false,
  apiUrl: 'http://localhost:8080/api'  // For local development
};
```

For production, update `environment.prod.ts`:

```typescript
export const environment = {
  production: true,
  apiUrl: 'https://api.yourdomain.com/api'  // Your production API
};
```

## Building Images

### Build All Images

```bash
docker-compose build
```

### Build Individual Services

```bash
# Backend only
docker-compose build backend

# Frontend only
docker-compose build frontend
```

### Build with No Cache (fresh build)

```bash
docker-compose build --no-cache
```

## Running the Application

### Start All Services

```bash
# Start in detached mode (background)
docker-compose up -d

# Start with logs visible
docker-compose up
```

### Start Specific Services

```bash
# Start only database and backend
docker-compose up -d postgres backend

# Start only frontend
docker-compose up -d frontend
```

### Check Service Status

```bash
# View running containers
docker-compose ps

# View service health
docker-compose ps --format json | jq
```

## Updating the Application

### Method 1: Code Changes (Development)

When you make code changes:

```bash
# 1. Stop the affected service
docker-compose stop backend  # or frontend

# 2. Rebuild the image
docker-compose build backend  # or frontend

# 3. Start the service
docker-compose up -d backend  # or frontend
```

**One-liner:**
```bash
# Backend update
docker-compose up -d --build backend

# Frontend update
docker-compose up -d --build frontend

# Update all
docker-compose up -d --build
```

### Method 2: Pull Latest Code (Production)

```bash
# 1. Pull latest code
git pull origin main

# 2. Rebuild and restart
docker-compose up -d --build

# 3. Verify
docker-compose ps
docker-compose logs -f backend frontend
```

### Method 3: Zero-Downtime Update (Production)

```bash
# 1. Build new images
docker-compose build

# 2. Start new containers
docker-compose up -d --no-deps --scale backend=2 backend

# 3. Stop old containers
docker-compose up -d --no-deps --scale backend=1 backend
```

## Database Management

### Access PostgreSQL

```bash
# Using docker-compose
docker-compose exec postgres psql -U postgres -d shopinow

# Using docker directly
docker exec -it shopinow-postgres psql -U postgres -d shopinow
```

### Backup Database

```bash
# Create backup
docker-compose exec postgres pg_dump -U postgres shopinow > backup_$(date +%Y%m%d_%H%M%S).sql

# Or using docker directly
docker exec shopinow-postgres pg_dump -U postgres shopinow > backup.sql
```

### Restore Database

```bash
# Restore from backup
cat backup.sql | docker-compose exec -T postgres psql -U postgres -d shopinow

# Or using docker directly
docker exec -i shopinow-postgres psql -U postgres -d shopinow < backup.sql
```

### Reset Database

```bash
# WARNING: This deletes all data!
docker-compose down -v
docker-compose up -d
```

## Logs and Debugging

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f backend
docker-compose logs -f frontend
docker-compose logs -f postgres

# Last 100 lines
docker-compose logs --tail=100 backend
```

### Execute Commands in Container

```bash
# Backend shell
docker-compose exec backend sh

# Check backend logs inside container
docker-compose exec backend cat /app/logs/shopinow-backend.log

# Frontend shell
docker-compose exec frontend sh

# Test backend health
docker-compose exec backend wget -O- http://localhost:8080/api/products
```

### Debug Issues

```bash
# Check container details
docker inspect shopinow-backend

# Check resource usage
docker stats

# Check network
docker network inspect shopinow-network

# Restart specific service
docker-compose restart backend
```

## Production Deployment

### 1. Update Configuration

```bash
# Create production .env
nano .env
```

```env
DB_PASSWORD=very_secure_production_password
JWT_SECRET=production_secret_key_256bits_minimum
CORS_ALLOWED_ORIGINS=https://yourdomain.com,https://www.yourdomain.com
```

### 2. Update Frontend API URL

Edit `ShopiNow/src/environments/environment.prod.ts`:

```typescript
export const environment = {
  production: true,
  apiUrl: 'https://api.yourdomain.com/api'
};
```

### 3. SSL/HTTPS Setup

For production, use a reverse proxy like Nginx or Traefik with Let's Encrypt.

**Example with Nginx:**

```nginx
# /etc/nginx/sites-available/shopinow
server {
    listen 80;
    server_name yourdomain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name yourdomain.com;

    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;

    # Frontend
    location / {
        proxy_pass http://localhost:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # Backend API
    location /api {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### 4. Build and Deploy

```bash
# Build production images
docker-compose build --no-cache

# Start services
docker-compose up -d

# Verify
docker-compose ps
docker-compose logs -f
```

### 5. Health Checks

```bash
# Check all services are healthy
docker-compose ps

# Manual health check
curl http://localhost:8080/api/products
curl http://localhost/
```

## Useful Commands

### Cleanup

```bash
# Remove stopped containers
docker-compose down

# Remove stopped containers and volumes
docker-compose down -v

# Remove all unused images
docker image prune -a

# Full cleanup (careful!)
docker system prune -a --volumes
```

### Monitoring

```bash
# Real-time resource usage
docker stats

# View container processes
docker-compose top

# Inspect service
docker-compose config
```

### Scaling

```bash
# Scale backend (multiple instances)
docker-compose up -d --scale backend=3

# Check instances
docker-compose ps
```

## Troubleshooting

### Backend won't start

```bash
# Check logs
docker-compose logs backend

# Check database connection
docker-compose exec backend wget -O- http://localhost:8080/api/products

# Verify environment variables
docker-compose exec backend env
```

### Frontend 404 errors

```bash
# Check nginx config
docker-compose exec frontend cat /etc/nginx/conf.d/default.conf

# Test nginx
docker-compose exec frontend nginx -t
```

### Database connection issues

```bash
# Check PostgreSQL is running
docker-compose ps postgres

# Test connection
docker-compose exec backend wget -O- postgres:5432

# Check logs
docker-compose logs postgres
```

### Port conflicts

```bash
# Check what's using port 8080
netstat -ano | findstr :8080  # Windows
lsof -i :8080                  # Linux/Mac

# Change port in docker-compose.yml
ports:
  - "8081:8080"  # Use 8081 instead
```

## Best Practices

1. **Never commit `.env` file** - add it to `.gitignore`
2. **Use strong passwords** in production
3. **Regular backups** of PostgreSQL data
4. **Monitor logs** regularly
5. **Use health checks** for all services
6. **Update images** regularly for security patches
7. **Use volumes** for persistent data
8. **Implement SSL/HTTPS** in production

---

**Need help?** Check the logs first with `docker-compose logs -f`

