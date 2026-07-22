# NTBK API

Ruby on Rails API backend for the NTBK note-taking application.

## Features

- **Authentication**: JWT-based auth with email/password and Google OAuth
- **User Settings**: Profile management, password change, connected accounts
- **Workspaces**: Create and manage multiple workspaces
- **Documents**: Create, edit, archive, and restore documents
- **Tags**: Organize documents with tags (auto-extracted from documents)
- **Search**: Full-text search using PostgreSQL (pg_search + pg_trgm)
- **AI Chat**: RAG-powered chat with semantic search
- **AI Summaries**: Generate document summaries
- **Smart Extraction**: Automatic text and tag extraction from uploaded files

## User Settings

Users can manage their profile and password from the Settings page:

- **Profile**: Update name (displayed as "Signed in as" instead of email)
- **Password**: Change password (email/password users) or set password (OAuth users)
- **Connected Accounts**: View linked OAuth providers

### OAuth User Behavior
- OAuth users see "Set Password" (optional, enables email/password login)
- Email/password users see "Change Password" (requires current password)
- After setting password, OAuth users can login with either method

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
git clone git@github.com:rkbart/ntbk-api.git
cd ntbk-api

# Install dependencies
bundle install

# Setup database
bin/rails db:create db:migrate

# Start server
bin/rails s
```

## API Endpoints

### Authentication
```
POST /api/v1/auth/register    - Register new user
POST /api/v1/auth/login       - Login with email/password
GET  /api/v1/auth/me          - Get current user
PATCH /api/v1/auth/me         - Update profile
POST /api/v1/auth/refresh     - Refresh JWT token
POST /api/v1/auth/google      - Google OAuth callback
```

### User Settings
```
GET    /api/v1/settings/profile    - Get user profile
PATCH  /api/v1/settings/profile    - Update profile (name, email)
PATCH  /api/v1/settings/password   - Change/set password
```

### Workspaces
```
GET    /api/v1/workspaces          - List workspaces
POST   /api/v1/workspaces          - Create workspace
GET    /api/v1/workspaces/:id      - Get workspace
PATCH  /api/v1/workspaces/:id      - Update workspace
DELETE /api/v1/workspaces/:id      - Delete workspace
```

### Documents
```
GET    /api/v1/workspaces/:wid/documents           - List documents
POST   /api/v1/workspaces/:wid/documents           - Create document
GET    /api/v1/workspaces/:wid/documents/:id       - Get document
PATCH  /api/v1/workspaces/:wid/documents/:id       - Update document
DELETE /api/v1/workspaces/:wid/documents/:id       - Delete document
POST   /api/v1/workspaces/:wid/documents/:id/archive - Archive document
POST   /api/v1/workspaces/:wid/documents/:id/restore - Restore document
GET    /api/v1/workspaces/:wid/documents/:id/summary - Get summary
POST   /api/v1/workspaces/:wid/documents/:id/summary - Generate summary
```

### Tags
```
GET    /api/v1/tags              - List tags
POST   /api/v1/tags              - Create tag
DELETE /api/v1/tags/:id          - Delete tag
```

### Search
```
GET    /api/v1/search?q=query    - Search documents
```

**Response includes**: `workspace_id` for correct navigation from search results.

### AI Features
```
POST   /api/v1/ai/embeddings           - Generate embeddings
POST   /api/v1/ai/embeddings/search    - Semantic search
POST   /api/v1/ai/chat                 - Chat with AI
POST   /api/v1/ai/chat/stream          - Stream chat
POST   /api/v1/workspaces/:id/summary  - Workspace summary
```

## Environment Variables

```bash
# Database
DATABASE_URL=postgresql://localhost:5432/ntbk_development

# JWT
JWT_SECRET_KEY=your-secret-key
JWT_EXPIRATION_HOURS=24

# Google OAuth
GOOGLE_CLIENT_ID=your-client-id
GOOGLE_CLIENT_SECRET=your-client-secret
GOOGLE_CALLBACK_URL=http://localhost:3000/users/auth/google_oauth2/callback

# AI (Optional)
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_EMBEDDING_MODEL=nomic-embed-text
OLLAMA_CHAT_MODEL=llama3.2:latest

# Frontend URL
FRONTEND_URL=http://localhost:5173
```

## Testing

```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/requests/api/v1/settings_spec.rb
```

## License

MIT
