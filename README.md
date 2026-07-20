# NTBK API

Ruby on Rails API backend for the NTBK note-taking application.

## Features

- **Authentication**: JWT-based auth with email/password and Google OAuth
- **Workspaces**: Create and manage multiple workspaces
- **Documents**: Create, edit, archive, and restore documents
- **Tags**: Organize documents with tags (auto-extracted from documents)
- **Search**: Full-text search using PostgreSQL (pg_search + pg_trgm)
- **AI Chat**: RAG-powered chat with semantic search
- **AI Summaries**: Generate document summaries
- **Smart Extraction**: Automatic text and tag extraction from uploaded files

## Smart Document Extraction

When uploading files, the system automatically:
1. Extracts text content (PDF, DOCX, TXT, MD, etc.)
2. Detects tags in common formats (YAML frontmatter, inline, array)
3. Creates and associates tags with the document
4. Removes tag sections from the document body
5. Uses cleaned content for RAG embeddings

### Supported Tag Formats
- YAML frontmatter: `tags:\n  - tag1\n  - tag2`
- Inline: `Tags: tag1, tag2, tag3`
- Array: `tags: [tag1, tag2]`

## Tech Stack

- **Framework**: Ruby on Rails 8.1.3
- **Language**: Ruby 3.4.10
- **Database**: PostgreSQL 16
- **AI**: Ollama/OpenAI/Anthropic
- **Vector Search**: pgvector (optional)

## Getting Started

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

## API Endpoints

### Authentication
- `POST /api/v1/auth/register` - Register
- `POST /api/v1/auth/login` - Login
- `GET /api/v1/auth/me` - Get profile
- `GET /users/auth/google_oauth2` - Google OAuth sign-in

### Workspaces
- `GET /api/v1/workspaces` - List workspaces
- `POST /api/v1/workspaces` - Create workspace
- `GET /api/v1/workspaces/:id` - Get workspace

### Documents
- `GET /api/v1/workspaces/:workspace_id/documents` - List documents
- `POST /api/v1/workspaces/:workspace_id/documents` - Create document
- `GET /api/v1/workspaces/:workspace_id/documents/:id` - Get document
- `PATCH /api/v1/workspaces/:workspace_id/documents/:id` - Update document
- `DELETE /api/v1/workspaces/:workspace_id/documents/:id` - Delete document

### AI
- `POST /api/v1/ai/chat` - Send message (with RAG)
- `GET /api/v1/ai/conversations` - List conversations
- `POST /api/v1/ai/conversations` - Create conversation

## License

MIT
