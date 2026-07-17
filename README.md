# NTBK

NTBK is a self-hosted note-taking platform focused on structured notes, Markdown editing, fast search, and AI-assisted knowledge retrieval.

## Ruby version

- Ruby 3.4.10

## System dependencies

- PostgreSQL 9.3+ (for database)
- libvips (for image processing)

## Configuration

### Database setup

This application uses PostgreSQL. Set the following environment variables as needed:

```bash
# Database connection (defaults shown)
export DB_USERNAME="postgres"
export DB_PASSWORD=""
export DB_HOST="localhost"
```

### Environment variables

- `RAILS_MASTER_KEY` - Required for production (get from `config/master.key`)
- `RAILS_MAX_THREADS` - Database connection pool size (default: 5)

## Database creation

```bash
# Create the databases
rails db:create

# Run migrations
rails db:migrate

# Seed the database (optional)
rails db:seed
```

## Database initialization

```bash
# Reset the database
rails db:reset

# Prepare database (create if needed, run migrations)
rails db:prepare
```

## How to run the test suite

```bash
# Run tests
rails test

# Or with rake
rake test
```

## Services

This application uses:

- **Solid Cache** - Database-backed cache store
- **Solid Queue** - Database-backed job queue
- **Solid Cable** - Database-backed Action Cable adapter

All services use the same PostgreSQL database with separate schemas.

## Deployment instructions

This application is designed to be deployed as a Docker container using [Kamal](https://kamal-deploy.org).

```bash
# Build the Docker image
docker build -t ntbk-api .

# Run the container
docker run -d -p 80:80 -e RAILS_MASTER_KEY=<value> -e DB_USERNAME=<username> -e DB_PASSWORD=<password> -e DB_HOST=<host> --name ntbk-api ntbk-api
```

For production deployment with Kamal:

```bash
kamal deploy
```

## Development

For a containerized development environment, see [Dev Containers](https://guides.rubyonrails.org/getting_started_with_devcontainer.html).