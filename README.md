# NTBK API

Ruby on Rails API backend for the NTBK note-taking application.

## Features

- **Authentication**: JWT-based auth with email/password and Google OAuth
- **Workspaces**: Create and manage multiple workspaces
- **Folders**: Organize documents with nested folder structure
- **Documents**: Create, edit, archive, and restore documents with attachments
- **Tags**: Organize documents with tags
- **Search**: Full-text search using PostgreSQL (pg_search + pg_trgm)
- **AI Chat**: RAG-powered chat with semantic search
- **AI Summaries**: Generate document summaries
- **Embeddings**: Vector search with pgvector (optional)

## Tech Stack

- **Framework**: Ruby on Rails 8.1.3
- **Language**: Ruby 3.4.10
- **Database**: PostgreSQL 16
- **Authentication**: JWT
- **AI**: Ollama/OpenAI/Anthropic
- **Vector Search**: pgvector (optional)

## Getting Started

### Prerequisites

- Ruby 3.4.10
- PostgreSQL 16
- Ollama (for AI features)

### Installation

```bash
# Clone the repository
git clone https://github.com/rkbart/ntbk-api.git
cd ntbk-api

# Install dependencies
bundle install

# Setup database
bin/rails db:setup

# Start server
bin/rails server
```

### Environment Variables

```env
DATABASE_URL=postgresql://localhost/ntbk_development
JWT_SECRET=your-secret-key
LLM_PROVIDER=ollama
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_CHAT_MODEL=llama3:8b
OLLAMA_EMBEDDING_MODEL=nomic-embed-text
```

## API Endpoints

### Authentication
- `POST /api/v1/auth/register` - Register new user
- `POST /api/v1/auth/login` - Login
- `GET /api/v1/auth/me` - Get current user
- `PATCH /api/v1/auth/me` - Update profile
- `POST /api/v1/auth/refresh` - Refresh token

### Workspaces
- `GET /api/v1/workspaces` - List workspaces
- `POST /api/v1/workspaces` - Create workspace
- `GET /api/v1/workspaces/:id` - Get workspace
- `PATCH /api/v1/workspaces/:id` - Update workspace

### Folders
- `GET /api/v1/workspaces/:workspace_id/folders` - List folders
- `POST /api/v1/workspaces/:workspace_id/folders` - Create folder
- `PATCH /api/v1/workspaces/:workspace_id/folders/:id` - Update folder
- `DELETE /api/v1/workspaces/:workspace_id/folders/:id` - Delete folder

### Documents
- `GET /api/v1/workspaces/:workspace_id/documents` - List documents
- `POST /api/v1/workspaces/:workspace_id/documents` - Create document
- `GET /api/v1/workspaces/:workspace_id/documents/:id` - Get document
- `PATCH /api/v1/workspaces/:workspace_id/documents/:id` - Update document
- `DELETE /api/v1/workspaces/:workspace_id/documents/:id` - Delete document
- `POST /api/v1/workspaces/:workspace_id/documents/:id/archive` - Archive
- `POST /api/v1/workspaces/:workspace_id/documents/:id/restore` - Restore

### Tags
- `GET /api/v1/tags` - List tags
- `POST /api/v1/tags` - Create tag
- `DELETE /api/v1/tags/:id` - Delete tag

### Search
- `GET /api/v1/search?q=...` - Full-text search

### AI
- `GET /api/v1/ai/conversations` - List conversations
- `POST /api/v1/ai/conversations` - Create conversation
- `GET /api/v1/ai/conversations/:id` - Get conversation
- `DELETE /api/v1/ai/conversations/:id` - Delete conversation
- `POST /api/v1/ai/chat` - Send message (with RAG)
- `POST /api/v1/ai/chat/stream` - Send message (streaming)
- `POST /api/v1/ai/embeddings/generate_workspace/:id` - Generate embeddings
- `POST /api/v1/ai/embeddings/search` - Semantic search

## RAG (Retrieval Augmented Generation)

The AI chat uses RAG to provide accurate answers based on your documents:

1. Documents are automatically embedded when created/updated
2. User queries are converted to embeddings
3. Semantically similar documents are retrieved
4. Only relevant documents are sent as context
5. LLM generates response based ONLY on provided documents

### Setup

1. Enable pgvector in PostgreSQL:
   ```sql
   CREATE EXTENSION IF NOT EXISTS vector;
   ```

2. Run migrations:
   ```bash
   bin/rails db:migrate
   ```

3. Generate embeddings for existing documents:
   ```bash
   curl -X POST http://localhost:3000/api/v1/ai/embeddings/generate_workspace/1 \
     -H "Authorization: Bearer <token>"
   ```

## Testing

```bash
# Run tests
bundle exec rspec

# Run linter
bundle exec rubocop
```

## Contributing

1. Create a feature branch from `main`
2. Make your changes
3. Run tests and linter
4. Create a pull request

## License

MIT
