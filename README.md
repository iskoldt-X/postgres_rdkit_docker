# PostgreSQL Docker Image with RDKit Cartridge

[![Build Multi-Arch Docker Image](https://github.com/protwis/postgres_rdkit_docker/actions/workflows/build_multi_arch.yml/badge.svg)](https://github.com/protwis/postgres_rdkit_docker/actions/workflows/build_multi_arch.yml)
[![GHCR](https://img.shields.io/badge/GHCR-ghcr.io%2Fprotwis%2Fpostgres__rdkit__docker-blue?logo=github)](https://github.com/protwis/postgres_rdkit_docker/pkgs/container/postgres_rdkit_docker)


A PostgreSQL 16 Docker image with the RDKit cartridge pre-installed and optimized for chemical informatics workloads.

This image inherits from the [official postgres image](https://hub.docker.com/_/postgres/), and therefore has all the same environment variables for configuration, and can be extended by adding entrypoint scripts to the `/docker-entrypoint-initdb.d` directory to be run on first launch.

## Features

- **Multi-architecture support**: Built for both AMD64 and ARM64 platforms
- **Optimized configuration**: Pre-configured `postgresql.conf`, tuned and measured against a
  26 GB GPCRdb database on a Mac development machine (see [Configuration](#configuration))
- **Planner cost hints included**: ships `rdkit-tuning.sql`, which lets bulk molecule builds use
  every core instead of one — measured 55.5 s to 6.9 s on 222,036 ligands
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
    image: ghcr.io/protwis/postgres_rdkit_docker:latest
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
    image: ghcr.io/protwis/postgres_rdkit_docker:latest
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
- Publishes to GitHub Container Registry as `ghcr.io/protwis/postgres_rdkit_docker`

See `.github/workflows/build_multi_arch.yml` for the build configuration.

### Manual Building

To build the image manually:

```bash
docker build -t ghcr.io/protwis/postgres_rdkit_docker:latest .
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
  -t ghcr.io/protwis/postgres_rdkit_docker:custom .
```

## Configuration

### PostgreSQL Configuration

The image includes a pre-configured `postgresql.conf` optimized for RDKit workloads.

> **What the defaults target.** This is a **development image**, and its default configuration is
> tuned for **a single developer on a Mac with Docker Desktop given ~12 CPUs and 16 GB RAM** —
> the environment in which the values below were measured, against a 26 GB GPCRdb database.
> It also suits comparable workstations (Apple Silicon, Oracle Cloud ARM) with ~10–16 GB available
> to the container.
>
> **If your environment differs, override the settings** — see
> [Adapting the configuration](#adapting-the-configuration).
>
> Two defaults in particular assume a single developer and will bite a multi-user deployment:
>
> - **`max_connections = 20`.** Ample for a dev server plus `psql` plus Adminer, but a multi-user
>   or multi-stack setup will fail with `FATAL: sorry, too many clients already`.
> - **`work_mem = 1GB` with `hash_mem_multiplier = 8`.** These limits apply **per sort/hash node,
>   per connection**, so they are only safe *because* the connection count is small. **If you raise
>   `max_connections`, lower `work_mem` in the same change.**
>
> On a small instance (e.g. 2 GB) you **must** lower `shared_buffers`, `effective_cache_size` and
> `work_mem` or the server will be OOM-killed. On a machine with few cores, lower
> `max_parallel_workers_per_gather`.

#### Memory Settings
- `shared_buffers = 2560MB`: measured optimum for a 16 GB container on a 26 GB database.
  Raising it was *slower* — memory reserved here is taken from the VM page cache, which serves a
  mostly-sequential working set better
- `effective_cache_size = 7GB`: measured optimum (4 GB and 12 GB both tested and slower)
- `work_mem = 1GB` and `hash_mem_multiplier = 8`: worth **~1.6×** on a `DISTINCT` over 24 million
  rows, where spilling dropped from ~300,000 blocks to zero. Safe here only in combination with
  `max_connections = 20` — see the note above
- `maintenance_work_mem = 512MB`: for vacuum and index creation

#### Storage/IO Optimizations
- `random_page_cost = 2.0`: chosen by sweeping 1.1 / 1.5 / 2.0 / 3.0 / 4.0. Below ~1.5 the planner
  switches RDKit GiST scans from Bitmap Heap Scan to plain Index Scan, which measured slower;
  2.0 was best across both chemistry and relational queries
- `effective_io_concurrency = 200`: prefetch depth for NVMe
- `min_wal_size = 4GB`, `max_wal_size = 8GB`: reduce checkpoint frequency during bulk loads
- `checkpoint_completion_target = 0.9`: spread checkpoint I/O load

#### Parallelism
- `max_worker_processes = 16`, `max_parallel_workers = 12`
- `max_parallel_workers_per_gather = 8`: the single most effective setting for GPCRdb's workload.
  Raising it from 4 to 8 was worth **1.6–2.8×** on large scans, aggregations and multi-table joins.
  **Lower this on machines with fewer than ~8 cores.**
- `max_parallel_maintenance_workers = 4`: helps B-tree index builds. Note it has no effect on RDKit
  GiST index builds, because PostgreSQL has no parallel GiST build

#### Query Planner
- `default_statistics_target = 100`: PostgreSQL's own default. Raising it to 200 made `ANALYZE`
  ~2.5× slower with no measurable query benefit on this workload
- `jit = off`: heavy aggregate queries measured 4.5–7.9% faster with JIT disabled. Set to `on` if
  your workload is dominated by long analytical queries that benefit from expression compilation

#### Connections & Safety
- `max_connections = 20`: sized for a single developer. A Django dev server holds single-digit
  connections (Django's default `CONN_MAX_AGE = 0` opens and closes one per request), leaving room
  for `psql` and Adminer. **Raise this for any multi-user deployment — and lower `work_mem` when
  you do.**
- `synchronous_commit = on`: ensure data durability
- `full_page_writes = on`: protect against partial page writes
- `listen_addresses = '*'`: listen on all interfaces

### Adapting the configuration

The quickest way to change a few settings is to append `-c` flags to the command — no rebuild and
no config file needed:

```yaml
# docker-compose.yml
services:
  db:
    image: ghcr.io/protwis/postgres_rdkit_docker:latest
    command: >
      postgres -c config_file=/etc/postgresql/postgresql.conf
               -c shared_buffers=512MB
               -c effective_cache_size=1536MB
               -c work_mem=16MB
               -c max_parallel_workers_per_gather=2
```

Suggested starting points for environments other than the default. These follow standard
PostgreSQL sizing practice (`shared_buffers` ≈ 25 % of available RAM, `effective_cache_size`
≈ 65–75 %, `work_mem` scaled down as `max_connections` goes up); only the 16 GB column was
measured on this image.

| Setting | 2 GB container | 8 GB container | 16 GB (**default, measured**) | 32 GB, many clients |
|---|---|---|---|---|
| `shared_buffers` | `512MB` | `2GB` | `2560MB` | `8GB` |
| `effective_cache_size` | `1536MB` | `6GB` | `7GB` | `24GB` |
| `work_mem` | `16MB` | `256MB` | `1GB` | `32MB` |
| `hash_mem_multiplier` | `2` | `4` | `8` | `2` |
| `max_connections` | `20` | `20` | `20` | `200` |
| `maintenance_work_mem` | `128MB` | `512MB` | `512MB` | `1GB` |
| `max_parallel_workers_per_gather` | `2` | `4` | `8` | `8` |
| `max_parallel_workers` | `4` | `8` | `12` | `16` |
| `min_wal_size` / `max_wal_size` | `256MB` / `1GB` | `1GB` / `4GB` | `4GB` / `8GB` | `4GB` / `16GB` |

Note how `work_mem` and `hash_mem_multiplier` move *down* in the 32 GB column even though the
machine is larger: that column assumes 200 concurrent clients, and the limits are per node per
connection. Memory sizing follows the connection count, not the machine.

Two rules of thumb worth stating explicitly, because both were measured here:

- **More `shared_buffers` is not better.** On a 16 GB container with a 26 GB database, 4 GB and 6 GB
  were both *slower* than 2560 MB. Memory given to PostgreSQL is taken away from the kernel page
  cache, and a large mostly-sequential working set is served better by the latter.
- **`max_parallel_workers_per_gather` should track core count, not RAM.** It is the highest-value
  setting for this workload on a many-core machine and a liability on a small one.

For a heavier rewrite, mount your own file:

```bash
docker run -d \
  --name postgres-rdkit \
  -v /path/to/custom/postgresql.conf:/etc/postgresql/postgresql.conf \
  -e POSTGRES_PASSWORD_FILE=/run/secrets/postgres_password \
  ghcr.io/protwis/postgres_rdkit_docker:latest \
  postgres -c config_file=/etc/postgresql/postgresql.conf
```

### Recommended: apply the cartridge planner hints

The image ships `/usr/local/share/postgresql/rdkit-tuning.sql`. Run it **once per database, after
`CREATE EXTENSION rdkit`** (for a Django project, after the migration that creates the extension):

```bash
docker exec -i <container> psql -U protwis -d protwis \
  -f /usr/local/share/postgresql/rdkit-tuning.sql
```

It is idempotent, changes no data and no query results, and is a no-op in a database without the
extension.

**Why it matters.** The cartridge declares its parsing functions `PARALLEL SAFE` and `IMMUTABLE`
but gives most of them no `COST`, so PostgreSQL prices them like an integer comparison. Measured on
this image, `mol_from_smiles(cstring)` costs ~123 µs per call — an underestimate of roughly five
orders of magnitude — so a bulk molecule build plans as a **serial** sequential scan even on a
12-core machine. On 222,036 real ligands:

| | time | workers |
|---|---:|---:|
| without the hints | 55.5 s | 0 |
| with `COST` applied | 14.1 s | 3 |
| with `COST` + relation-level `parallel_workers` (both in the file) | **6.9 s** | 8 |

The script cannot run automatically at container start, because the extension is created by the
application's migrations rather than at `initdb` time.

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
- `work_mem = 1GB`, `hash_mem_multiplier = 8`: maximum RAM per sort/hash node, per connection,
  before spilling to disk

These settings increase the RAM requirements for PostgreSQL. Ensure your container has sufficient memory allocated.

### Is `work_mem = 1GB` safe?

It is, for the single-developer profile this image targets — and the reasoning is worth stating,
because the arithmetic looks alarming at first.

The theoretical worst case is `work_mem × hash_mem_multiplier × (workers + 1)` per node, which with
these defaults is far more memory than a 16 GB container has. In practice PostgreSQL's hash nodes
are **budget-aware and spill to disk** rather than exceeding their allowance. Measured on this image
with a deliberately hostile query — a forced parallel `HashAggregate` with `array_agg` over
24 million rows — the query used **1.27 GB of memory plus 744 MB of disk spill**, partitioned itself
into 8 batches, and peaked at **6.11 GiB of the container's 15.6 GiB** with no OOM and every backend
surviving. `hash_mem_multiplier` raises the *ceiling*, not the actual usage.

What makes it safe is `max_connections = 20`. The limit is per node **per connection**, so the
safety argument is about concurrency, not about the machine's size.

**For a multi-user deployment**, either scale `work_mem` down as you raise `max_connections`, or
keep the connection count high and grant the memory to a single role:

```sql
CREATE ROLE analytics LOGIN CONNECTION LIMIT 2;
ALTER ROLE analytics SET work_mem = '1GB';
ALTER ROLE analytics SET hash_mem_multiplier = 8;
```

To verify your own configuration under load, read `Memory Usage`, `Batches` and `Disk Usage` from
`EXPLAIN (ANALYZE, BUFFERS)` and check the container's `memory.events` oom counter.

Source: [RDKit Cartridge Configuration](https://www.rdkit.org/docs/Cartridge.html#configuration)

For more information, see the [RDKit PostgreSQL Cartridge documentation](https://www.rdkit.org/docs/Cartridge.html).

## Image Details

- **Base Image**: `postgres:16-bookworm`
- **RDKit Version**: Release_2025_03_1
- **PostgreSQL Version**: 16
- **Architectures**: linux/amd64, linux/arm64
- **Image Size**: ~262 MB compressed (what `docker pull` transfers), ~1.12 GB on disk after extraction

## License

See [LICENSE](LICENSE) file for details.
