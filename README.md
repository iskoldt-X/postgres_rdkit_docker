# PostgreSQL Docker Image with RDKit Cartridge

[![Build Multi-Arch Docker Image](https://github.com/protwis/postgres_rdkit_docker/actions/workflows/build_multi_arch.yml/badge.svg)](https://github.com/protwis/postgres_rdkit_docker/actions/workflows/build_multi_arch.yml)


A PostgreSQL 16 Docker image with the RDKit cartridge pre-installed and optimized for chemical informatics workloads.

This image inherits from the [official postgres image](https://hub.docker.com/_/postgres/), and therefore has all the same environment variables for configuration, and can be extended by adding entrypoint scripts to the `/docker-entrypoint-initdb.d` directory to be run on first launch.

## Features

- **Multi-architecture support**: Built for both AMD64 and ARM64 platforms
- **Optimized configuration**: Pre-configured `postgresql.conf` with RDKit-optimized settings
- **Automated builds**: Images are automatically built and published via GitHub Actions
- **Modern Dockerfile**: Multi-stage build for smaller image size and faster builds
- **PostgreSQL 16**: Based on the latest PostgreSQL 16 (bookworm) image
- **RDKit 2025.03.1**: The latest release compatible with Debian 12 (Bookworm) and its system Boost libraries (v1.74), ensuring maximum stability without experimental dependencies.

## Quick Start with Docker Compose

Follow these steps to get PostgreSQL with RDKit running in minutes. Choose the instructions for your operating system.

---

### macOS / Linux

#### Step 1: Create Project Directory

```bash
mkdir -p ~/GPCRdb && cd ~/GPCRdb
```

#### Step 2: Create Docker Network and Volume

```bash
docker network create gpcrdb
docker volume create postgres_data
```

#### Step 3: Create `docker-compose.yml`

Copy and paste this entire block into your terminal:

```bash
cat > docker-compose.yml << 'EOF'
services:
  db:
    image: ghcr.io/protwis/postgres16-rdkit:latest
    container_name: postgres-rdkit
    restart: always
    shm_size: 2g

    environment:
      - POSTGRES_USER=protwis
      - POSTGRES_PASSWORD=protwis
      - POSTGRES_DB=protwis
      - PGDATA=/var/lib/postgresql/data

    ports:
      - "5432:5432"

    volumes:
      - postgres_data:/var/lib/postgresql/data
    
    networks:
      - gpcrdb

    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U protwis"]
      interval: 10s
      timeout: 5s
      retries: 5

  adminer:
    image: adminer
    container_name: adminer
    restart: always
    ports:
      - "8888:8080"
    environment:
      - ADMINER_DEFAULT_SERVER=db
    networks:
      - gpcrdb
    depends_on:
      db:
        condition: service_healthy

networks:
  gpcrdb:
    external: true

volumes:
  postgres_data:
    external: true
EOF
```

#### Step 4: Start the Services

```bash
docker compose up -d
```

#### Step 5: Verify

- **PostgreSQL**: Connect to `localhost:5432` with user `protwis` and password `protwis`
- **Adminer**: Open http://localhost:8888 in your browser to manage the database
Adminer server: on macOS, set `Server` to `host.docker.internal`; on Windows, set `Server` to `postgres-rdkit` (the DB container name).

---

### Windows (PowerShell)

#### Step 1: Create Project Directory

```powershell
mkdir $env:USERPROFILE\Desktop\GPCRdb
cd $env:USERPROFILE\Desktop\GPCRdb
```

#### Step 2: Create Docker Network and Volume

```powershell
docker network create gpcrdb
docker volume create postgres_data
```

#### Step 3: Create `docker-compose.yml`

Copy and paste this entire block into PowerShell:

```powershell
@'
services:
  db:
    image: ghcr.io/protwis/postgres16-rdkit:latest
    container_name: postgres-rdkit
    restart: always
    shm_size: 2g

    environment:
      - POSTGRES_USER=protwis
      - POSTGRES_PASSWORD=protwis
      - POSTGRES_DB=protwis
      - PGDATA=/var/lib/postgresql/data

    ports:
      - "5432:5432"

    volumes:
      - postgres_data:/var/lib/postgresql/data
    
    networks:
      - gpcrdb

    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U protwis"]
      interval: 10s
      timeout: 5s
      retries: 5

  adminer:
    image: adminer
    container_name: adminer
    restart: always
    ports:
      - "8888:8080"
    environment:
      - ADMINER_DEFAULT_SERVER=db
    networks:
      - gpcrdb
    depends_on:
      db:
        condition: service_healthy

networks:
  gpcrdb:
    external: true

volumes:
  postgres_data:
    external: true
'@ | Out-File -Encoding utf8 docker-compose.yml
```

#### Step 4: Start the Services

```powershell
docker compose up -d
```

#### Step 5: Verify

- **PostgreSQL**: Connect to `localhost:5432` with user `protwis` and password `protwis`
- **Adminer**: Open http://localhost:8888 in your browser to manage the database
Adminer server: on macOS, set `Server` to `host.docker.internal`; on Windows, set `Server` to `postgres-rdkit` (the DB container name).

### Stop and Remove

```bash
# Stop the services
docker compose down

# To also remove the data volume (WARNING: deletes all data!)
docker volume rm postgres_data
```

## Loading Database Dump

### Download the Database Dump

Download the latest GPCRdb database dump from [files.gpcrdb.org](https://files.gpcrdb.org/):

```bash
curl -L https://files.gpcrdb.org/protwis_sp.sql.gz -o ~/protwis.sql.gz
```

### First-Time Setup

If you're loading the database for the first time (fresh `postgres_data` volume):

```bash
time gunzip -c ~/protwis.sql.gz | docker exec -i postgres-rdkit psql -U protwis -d protwis -q -1
```

> [!TIP]
> The `-q` flag suppresses output, and `-1` wraps the entire import in a single transaction for better performance and atomicity.

### Resetting Existing Data

If you've previously loaded data and want to start fresh:

1. **Stop all services using the database**:
   ```bash
   docker compose down
   ```

2. **Remove the existing data volume**:
   ```bash
   docker volume rm postgres_data
   ```

3. **Recreate the volume and restart services**:
   ```bash
   docker volume create postgres_data
   docker compose up -d
   ```

4. **(Optional) Restart Docker Desktop** to clear memory (recommended on macOS/Windows)

5. **Wait for the database to be ready**, then load the dump:
   ```bash
   # Wait for healthcheck to pass
   docker compose ps

   # Load the dump
   time gunzip -c ~/protwis.sql.gz | docker exec -i postgres-rdkit psql -U protwis -d protwis -q -1
   ```

### Windows Instructions

Windows does not have `gunzip` or `time` by default. Use PowerShell instead:

#### Download the Database Dump (PowerShell)

```powershell
# Download to your Downloads folder
curl.exe -L -o "$env:USERPROFILE\Downloads\protwis.sql.gz" "https://files.gpcrdb.org/protwis_sp.sql.gz"
```

#### Load the Dump (PowerShell)




**Using gzip via Docker** (no extra software needed):

```powershell
# Copy the gzipped file into the container
docker cp "$env:USERPROFILE\Downloads\protwis.sql.gz" postgres-rdkit:/tmp/protwis.sql.gz

# Decompress and load inside the container
docker exec postgres-rdkit bash -c "gunzip -c /tmp/protwis.sql.gz | psql -U protwis -d protwis -q -1"

# Clean up
docker exec postgres-rdkit rm /tmp/protwis.sql.gz
```



This image exposes port 5432 (the postgres port), so standard container linking will make it automatically available to the linked containers.

## Environment Variables

- `POSTGRES_PASSWORD`: Superuser password for PostgreSQL (use `POSTGRES_PASSWORD_FILE` for secrets instead).
- `POSTGRES_USER`: Superuser username (default `postgres`).
- `POSTGRES_DB`: Default database that is created when the image is first started.
- `PGDATA`: Location for the database files (default `/var/lib/postgresql/data`).

See the [official postgres image](https://hub.docker.com/_/postgres/) for more details.

## Building

### Automated Builds via GitHub Actions

Images are automatically built and published to GitHub Container Registry (ghcr.io) via GitHub Actions when:
- Code is pushed to the `main` branch
- The workflow is manually triggered

The build process:
- Builds multi-architecture images (AMD64 and ARM64)
- Tags images with both `latest` and date-based versions (YYYY.MM.DD format)
- Publishes to GitHub Container Registry as `ghcr.io/protwis/postgres16-rdkit`

See `.github/workflows/build_multi_arch.yml` for the build configuration.

### Manual Building

To build the image manually:

```bash
docker build -t ghcr.io/protwis/postgres16-rdkit:latest .
```

The Dockerfile uses a multi-stage build:
- **Stage 1 (Builder)**: Compiles RDKit from source on `postgres:16-bookworm`
- **Stage 2 (Final)**: Creates the final image with only runtime dependencies

Build arguments:
- `RDKIT_VERSION`: RDKit version to build (default: `Release_2025_03_1`)

Example with custom RDKit version:

```bash
docker build \
  --build-arg RDKIT_VERSION=Release_2024_09_2 \
  -t ghcr.io/protwis/postgres16-rdkit:custom .
```

## Configuration

### PostgreSQL Configuration

The image includes a pre-configured `postgresql.conf` optimized for RDKit workloads. Key settings include:

> **Note**: The default configuration is tuned for a high-performance workstation (e.g., Apple M2 Max, Oracle Cloud ARM) with ~10-12GB RAM available. If running on a smaller instance (e.g., 2GB RAM), you MUST override `shared_buffers` and `work_mem` via command line flags or a custom config file to avoid OOM crashes.

#### Memory Settings
- `shared_buffers = 2560MB`: 25% of 10GB container RAM
- `effective_cache_size = 7GB`: ~70% of 10GB container RAM
- `work_mem = 64MB`: Per-query memory limit
- `maintenance_work_mem = 512MB`: For vacuum and index creation

#### Storage/IO Optimizations
- `random_page_cost = 1.1`: Optimized for NVMe SSD
- `effective_io_concurrency = 200`: High concurrency for NVMe
- `min_wal_size = 1GB`: Reduce checkpoint frequency
- `max_wal_size = 4GB`: Limit WAL disk usage
- `checkpoint_completion_target = 0.9`: Spread checkpoint I/O load

#### Parallelism
- `max_worker_processes = 10`: Allow background workers + parallel queries
- `max_parallel_workers = 8`: Utilize performance cores
- `max_parallel_workers_per_gather = 4`: Limit parallel workers per query

#### Connections & Safety
- `max_connections = 200`: Support expected concurrent users
- `synchronous_commit = on`: Ensure data durability
- `full_page_writes = on`: Protect against partial page writes
- `listen_addresses = '*'`: Listen on all interfaces

### Customizing Configuration

To use your own `postgresql.conf`:

```bash
docker run -d \
  --name postgres-rdkit \
  -v /path/to/custom/postgresql.conf:/etc/postgresql/postgresql.conf \
  -e POSTGRES_PASSWORD_FILE=/run/secrets/postgres_password \
  ghcr.io/protwis/postgres16-rdkit:latest \
  postgres -c config_file=/etc/postgresql/postgresql.conf
```

## Performance Optimization

The included `postgresql.conf` is already optimized for RDKit workloads. However, if you need to further optimize for specific use cases:

### For Building the Database (High-Volume Inserts)

If you're doing bulk inserts and building indexes, you can temporarily adjust these settings (at the cost of data safety):

```sql
-- WARNING: These settings reduce data safety
ALTER SYSTEM SET synchronous_commit = 'off';
ALTER SYSTEM SET full_page_writes = 'off';
SELECT pg_reload_conf();
```

**Warning**: 
- `synchronous_commit = off`: Speeds normal operation but increases the chance of losing commits if PostgreSQL crashes. Commits will be reported as executed even if not stored and flushed to durable storage.
- `full_page_writes = off`: Speeds normal operation but might lead to unrecoverable or silent data corruption after a system failure.

**Recommendation**: Only use these settings during initial data loading. To revert to production safety:

```sql
-- Revert to safe production defaults
ALTER SYSTEM RESET synchronous_commit;
ALTER SYSTEM RESET full_page_writes;
SELECT pg_reload_conf();
```

### For Queries (Structural Searches)

The default configuration already includes optimized memory settings:
- `shared_buffers = 2560MB`: PostgreSQL's dedicated RAM
- `work_mem = 64MB`: Maximum RAM per query operation before using disk

These settings increase the RAM requirements for PostgreSQL. Ensure your container has sufficient memory allocated.

Source: [RDKit Cartridge Configuration](https://www.rdkit.org/docs/Cartridge.html#configuration)

For more information, see the [RDKit PostgreSQL Cartridge documentation](https://www.rdkit.org/docs/Cartridge.html).

## Image Details

- **Base Image**: `postgres:16-bookworm`
- **RDKit Version**: Release_2025_03_1
- **PostgreSQL Version**: 16
- **Architectures**: linux/amd64, linux/arm64
- **Image Size**: ~813 MB

## License

See [LICENSE](LICENSE) file for details.
