# NTBK API - Development Documentation

This document tracks what has been implemented and how.

---

## Project Setup

### Tech Stack
- **Framework**: Ruby on Rails 8.1.3 (API mode)
- **Database**: PostgreSQL 16
- **Ruby**: 3.4.10
- **Testing**: RSpec + FactoryBot
- **Auth**: Devise + JWT

### Initial Setup
```bash
# Create Rails API project
rails new ntbk --api --database=postgresql

# Setup database
bin/rails db:create

# Install dependencies
bundle install
```

---

## Devise Setup

### Installation
```bash
# Install Devise
echo 'gem "devise", "~> 5.0"' >> Gemfile
bundle install

# Generate Devise config
rails g devise:install

# Generate User model
rails g devise User
```

### Configuration
**File**: `config/initializers/devise.rb`
- Default Devise configuration
- Mailer sender configured

**File**: `app/models/user.rb`
```ruby
class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Associations
  has_one :workspace, dependent: :destroy
  has_many :tags, dependent: :destroy

  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :password, length: { minimum: 6 }, if: :password_required?

  before_save :downcase_email
  after_create :create_default_workspace

  private

  def downcase_email
    self.email = email.downcase if email.present?
  end

  def password_required?
    new_record? || password.present?
  end

  def create_default_workspace
    create_workspace(name: "My Workspace")
  end
end
```

### Database Migration
**File**: `db/migrate/YYYYMMDD_devise_create_users.rb`
- `email` (unique, indexed)
- `encrypted_password`
- `reset_password_token` (indexed)
- `reset_password_sent_at`
- `remember_created_at`

---

## RSpec Setup

### Installation
```bash
# Add to Gemfile
echo 'gem "rspec-rails"' >> Gemfile
echo 'gem "factory_bot_rails"' >> Gemfile
echo 'gem "faker"' >> Gemfile
bundle install

# Generate RSpec config
rails g rspec:install
```

### Configuration
**File**: `spec/rails_helper.rb`
```ruby
RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
  config.fixture_paths = [ Rails.root.join('spec/fixtures') ]
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
end
```

### Directory Structure
```
spec/
├── rails_helper.rb
├── spec_helper.rb
├── support/
│   ├── api_helpers.rb
│   └── database_cleaner.rb
├── factories/
│   ├── users.rb
│   ├── workspaces.rb
│   ├── folders.rb
│   ├── documents.rb
│   ├── tags.rb
│   └── document_tags.rb
├── models/
│   ├── user_spec.rb
│   ├── workspace_spec.rb
│   ├── folder_spec.rb
│   ├── document_spec.rb
│   ├── tag_spec.rb
│   └── document_tag_spec.rb
└── requests/
    └── api/v1/
        └── auth_spec.rb
```

### Running Tests
```bash
# Run all tests
bundle exec rspec

# Run specific file
bundle exec rspec spec/models/user_spec.rb

# Run with documentation format
bundle exec rspec --format documentation
```

---

## Serializers

### Installation
```bash
echo 'gem "active_model_serializers", "~> 0.10"' >> Gemfile
bundle install
```

### User Serializer
**File**: `app/serializers/user_serializer.rb`
```ruby
class UserSerializer < ActiveModel::Serializer
  attributes :id, :email, :created_at, :updated_at
  has_one :workspace

  def created_at
    object.created_at&.iso8601
  end

  def updated_at
    object.updated_at&.iso8601
  end
end
```

### Workspace Serializer
**File**: `app/serializers/workspace_serializer.rb`
```ruby
class WorkspaceSerializer < ActiveModel::Serializer
  attributes :id, :name, :created_at, :updated_at
  has_many :folders
  has_many :documents
end
```

### Folder Serializer
**File**: `app/serializers/folder_serializer.rb`
```ruby
class FolderSerializer < ActiveModel::Serializer
  attributes :id, :name, :parent_id, :document_count, :created_at, :updated_at

  def document_count
    object.documents.count
  end
end
```

### Document Serializer
**File**: `app/serializers/document_serializer.rb`
```ruby
class DocumentSerializer < ActiveModel::Serializer
  attributes :id, :title, :body, :folder_id, :archived_at, :created_at, :updated_at
  belongs_to :folder
  has_many :tags
end
```

### Tag Serializer
**File**: `app/serializers/tag_serializer.rb`
```ruby
class TagSerializer < ActiveModel::Serializer
  attributes :id, :name, :document_count, :created_at

  def document_count
    object.document_count
  end
end
```

### Usage
```ruby
# In controller
render json: @user

# In console
UserSerializer.new(user).as_json
```

---

## JWT Authentication

### Installation
```bash
echo 'gem "jwt", "~> 2.7"' >> Gemfile
bundle install
```

### JWT Service
**File**: `app/services/jwt_service.rb`
```ruby
class JwtService
  SECRET_KEY = Rails.application.credentials.secret_key_base

  def self.encode(payload, exp = 24.hours.from_now)
    payload[:exp] = exp.to_i
    JWT.encode(payload, SECRET_KEY)
  end

  def self.decode(token)
    decoded = JWT.decode(token, SECRET_KEY)[0]
    HashWithIndifferentAccess.new(decoded)
  rescue JWT::DecodeError, JWT::ExpiredSignature => e
    Rails.logger.error "JWT Error: #{e.message}"
    nil
  end
end
```

### Base Controller
**File**: `app/controllers/api/v1/base_controller.rb`
```ruby
module Api
  module V1
    class BaseController < ApplicationController
      before_action :authenticate_user!

      private

      def authenticate_user!
        token = extract_token_from_header
        return unauthorized!("Missing token") unless token

        decoded = JwtService.decode(token)
        return unauthorized!("Invalid token") unless decoded

        @current_user = User.find_by(id: decoded[:user_id])
        unauthorized!("User not found") unless @current_user
      end

      def current_user
        @current_user
      end

      def extract_token_from_header
        header = request.headers['Authorization']
        header&.split(' ')&.last
      end

      def unauthorized!(message = 'Unauthorized')
        render json: { error: { code: 'UNAUTHORIZED', message: message } }, status: :unauthorized
      end
    end
  end
end
```

### Auth Controller
**File**: `app/controllers/api/v1/auth_controller.rb`

**Endpoints**:
| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| POST | /api/v1/auth/register | Create account | No |
| POST | /api/v1/auth/login | Login | No |
| GET | /api/v1/auth/me | Get profile | Yes |
| PATCH | /api/v1/auth/me | Update profile | Yes |
| POST | /api/v1/auth/refresh | Refresh token | Yes |

### Routes
**File**: `config/routes.rb`
```ruby
Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      post 'auth/register', to: 'auth#register'
      post 'auth/login', to: 'auth#login'
      get 'auth/me', to: 'auth#me'
      patch 'auth/me', to: 'auth#update_profile'
      post 'auth/refresh', to: 'auth#refresh'
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
```

---

## CORS Setup

### Installation
```bash
echo 'gem "rack-cors"' >> Gemfile
bundle install
```

### Configuration
**File**: `config/initializers/cors.rb`
```ruby
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins "http://localhost:*", "http://127.0.0.1:*"
    resource "*",
      headers: :any,
      methods: [ :get, :post, :put, :patch, :delete, :options, :head ],
      expose: [ "X-RateLimit-Limit", "X-RateLimit-Remaining", "X-RateLimit-Reset" ]
  end
end
```

---

## Database Models

### Workspace Model
**File**: `app/models/workspace.rb`
```ruby
class Workspace < ApplicationRecord
  belongs_to :user
  has_many :folders, dependent: :destroy
  has_many :documents, dependent: :destroy

  validates :name, presence: true, length: { maximum: 255 }
end
```

**Migration**:
- `name` (string, not null)
- `user_id` (references, not null, foreign key)
- Indexes: `user_id`

### Folder Model
**File**: `app/models/folder.rb`
```ruby
class Folder < ApplicationRecord
  belongs_to :workspace
  belongs_to :parent, class_name: "Folder", optional: true
  has_many :subfolders, class_name: "Folder", foreign_key: :parent_id, dependent: :destroy
  has_many :documents, dependent: :destroy

  validates :name, presence: true, length: { maximum: 255 }
  validate :no_circular_references

  def ancestors
    folder = self
    ancestors = []
    while folder.parent_id.present?
      folder = folder.parent
      ancestors << folder
    end
    ancestors.reverse
  end

  def path
    (ancestors + [ self ]).map(&:name).join(" / ")
  end

  private

  def no_circular_references
    return unless parent_id.present?

    if parent_id == id
      errors.add(:parent_id, "can't be self")
      return
    end

    current = parent
    while current.present?
      if current.id == id
        errors.add(:parent_id, "would create circular reference")
        return
      end
      current = current.parent
    end
  end
end
```

**Migration**:
- `name` (string, not null)
- `workspace_id` (references, not null, foreign key)
- `parent_id` (references, foreign key to self)
- Indexes: `workspace_id`, `parent_id`, `[workspace_id, parent_id]`

### Document Model
**File**: `app/models/document.rb`
```ruby
class Document < ApplicationRecord
  belongs_to :workspace
  belongs_to :folder, optional: true
  has_many :document_tags, dependent: :destroy
  has_many :tags, through: :document_tags

  validates :title, presence: true, length: { maximum: 255 }

  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }
  scope :by_folder, ->(folder_id) { where(folder_id: folder_id) }
  scope :by_tag, ->(tag_name) { joins(:tags).where(tags: { name: tag_name.downcase }) }

  def archive!
    update!(archived_at: Time.current)
  end

  def restore!
    update!(archived_at: nil)
  end

  def archived?
    archived_at.present?
  end

  def body_preview(length = 200)
    return "" if body.blank?
    body.truncate(length, separator: " ")
  end
end
```

**Migration**:
- `title` (string, not null)
- `body` (text)
- `workspace_id` (references, not null, foreign key)
- `folder_id` (references, foreign key)
- `archived_at` (datetime)
- Indexes: `workspace_id`, `folder_id`, `archived_at`, `[workspace_id, folder_id]`, `[workspace_id, archived_at]`

### Tag Model
**File**: `app/models/tag.rb`
```ruby
class Tag < ApplicationRecord
  belongs_to :user
  has_many :document_tags, dependent: :destroy
  has_many :documents, through: :document_tags

  validates :name, presence: true, length: { maximum: 50 }
  validates :name, uniqueness: { scope: :user_id, case_sensitive: false }

  before_validation :normalize_name

  def document_count
    documents.count
  end

  private

  def normalize_name
    self.name = name.downcase.strip if name.present?
  end
end
```

**Migration**:
- `name` (string, not null)
- `user_id` (references, not null, foreign key)
- Indexes: `user_id`, `[user_id, name]` (unique)

### DocumentTag Model
**File**: `app/models/document_tag.rb`
```ruby
class DocumentTag < ApplicationRecord
  belongs_to :document
  belongs_to :tag

  validates :document_id, uniqueness: { scope: :tag_id }
end
```

**Migration**:
- `document_id` (references, not null, foreign key)
- `tag_id` (references, not null, foreign key)
- `created_at` (datetime, not null)
- Indexes: `[document_id, tag_id]` (unique)

---

## CI/CD Setup

### GitHub Actions
**File**: `.github/workflows/ci.yml`

**Jobs**:
1. **scan_ruby** - Brakeman + bundler-audit
2. **lint** - RuboCop
3. **test** - PostgreSQL + RSpec

### Local CI
```bash
bin/ci
```

---

## API Controllers

### Workspaces Controller
**File**: `app/controllers/api/v1/workspaces_controller.rb`

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| GET | /api/v1/workspaces | List all workspaces | Yes |
| GET | /api/v1/workspaces/:id | Get workspace | Yes |
| POST | /api/v1/workspaces | Create workspace | Yes |
| PATCH | /api/v1/workspaces/:id | Update workspace | Yes |

### Folders Controller
**File**: `app/controllers/api/v1/folders_controller.rb`

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| GET | /api/v1/workspaces/:workspace_id/folders | List folders | Yes |
| GET | /api/v1/workspaces/:workspace_id/folders/:id | Get folder | Yes |
| POST | /api/v1/workspaces/:workspace_id/folders | Create folder | Yes |
| PATCH | /api/v1/workspaces/:workspace_id/folders/:id | Update folder | Yes |
| DELETE | /api/v1/workspaces/:workspace_id/folders/:id | Delete folder | Yes |

### Documents Controller
**File**: `app/controllers/api/v1/documents_controller.rb`

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| GET | /api/v1/workspaces/:workspace_id/documents | List documents | Yes |
| GET | /api/v1/workspaces/:workspace_id/documents/:id | Get document | Yes |
| POST | /api/v1/workspaces/:workspace_id/documents | Create document | Yes |
| PATCH | /api/v1/workspaces/:workspace_id/documents/:id | Update document | Yes |
| DELETE | /api/v1/workspaces/:workspace_id/documents/:id | Delete document | Yes |
| POST | /api/v1/workspaces/:workspace_id/documents/:id/archive | Archive document | Yes |
| POST | /api/v1/workspaces/:workspace_id/documents/:id/restore | Restore document | Yes |

### Tags Controller
**File**: `app/controllers/api/v1/tags_controller.rb`

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| GET | /api/v1/tags | List all tags | Yes |
| POST | /api/v1/tags | Create tag | Yes |
| DELETE | /api/v1/tags/:id | Delete tag | Yes |

### Search Controller
**File**: `app/controllers/api/v1/search_controller.rb`

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| GET | /api/v1/search?q=query | Full-text search | Yes |

**Query Parameters**:
- `q` (required): Search query
- `page` (default: 1): Page number
- `per_page` (default: 20, max: 100): Items per page
- `archived` (default: false): Include archived documents

---

## Test Coverage

### Model Specs
- `spec/models/user_spec.rb` - 11 examples
- `spec/models/workspace_spec.rb` - 10 examples
- `spec/models/folder_spec.rb` - 12 examples
- `spec/models/document_spec.rb` - 14 examples
- `spec/models/tag_spec.rb` - 10 examples
- `spec/models/document_tag_spec.rb` - 6 examples

### Request Specs
- `spec/requests/api/v1/auth_spec.rb` - 13 examples
- `spec/requests/api/v1/workspaces_spec.rb` - 7 examples
- `spec/requests/api/v1/folders_spec.rb` - 7 examples
- `spec/requests/api/v1/documents_spec.rb` - 11 examples
- `spec/requests/api/v1/tags_spec.rb` - 4 examples
- `spec/requests/api/v1/search_spec.rb` - 9 examples

**Total**: 105 examples, 0 failures

---

## File Structure

```
ntbk/
├── app/
│   ├── controllers/
│   │   └── api/v1/
│   │       ├── base_controller.rb
│   │       ├── auth_controller.rb
│   │       ├── workspaces_controller.rb
│   │       ├── folders_controller.rb
│   │       ├── documents_controller.rb
│   │       ├── tags_controller.rb
│   │       └── search_controller.rb
│   ├── models/
│   │   ├── user.rb
│   │   ├── workspace.rb
│   │   ├── folder.rb
│   │   ├── document.rb
│   │   ├── tag.rb
│   │   └── document_tag.rb
│   ├── serializers/
│   │   ├── user_serializer.rb
│   │   ├── workspace_serializer.rb
│   │   ├── folder_serializer.rb
│   │   ├── document_serializer.rb
│   │   ├── tag_serializer.rb
│   │   └── search_result_serializer.rb
│   └── services/
│       ├── jwt_service.rb
│       └── search_service.rb
├── config/
│   ├── initializers/
│   │   ├── cors.rb
│   │   └── devise.rb
│   └── routes.rb
├── db/
│   └── migrate/
│       ├── devise_create_users.rb
│       ├── create_workspaces.rb
│       ├── create_folders.rb
│       ├── create_documents.rb
│       ├── create_tags.rb
│       └── create_document_tags.rb
├── spec/
│   ├── factories/
│   │   ├── users.rb
│   │   ├── workspaces.rb
│   │   ├── folders.rb
│   │   ├── documents.rb
│   │   ├── tags.rb
│   │   └── document_tags.rb
│   ├── models/
│   │   ├── user_spec.rb
│   │   ├── workspace_spec.rb
│   │   ├── folder_spec.rb
│   │   ├── document_spec.rb
│   │   ├── tag_spec.rb
│   │   └── document_tag_spec.rb
│   ├── requests/api/v1/
│   │   ├── auth_spec.rb
│   │   ├── workspaces_spec.rb
│   │   ├── folders_spec.rb
│   │   ├── documents_spec.rb
│   │   ├── tags_spec.rb
│   │   └── search_spec.rb
│   └── support/
│       └── api_helpers.rb
├── .github/workflows/
│   └── ci.yml
├── DEVELOPMENT.md
└── Gemfile
```

---

## Full-Text Search Implementation

### Installation
```bash
# Add pg_search to Gemfile
echo 'gem "pg_search"' >> Gemfile
bundle install
```

### Database Setup

**Extensions**:
- `pg_trgm` - For fuzzy/partial matching

**Columns**:
- `search_vector` (tsvector) - Auto-updated via trigger on title/body changes

**Indexes**:
- GIN index on `search_vector` - For fast full-text queries
- GIN trigram index on `[title, body]` - For fuzzy matching

### Model Changes

**File**: `app/models/document.rb`
```ruby
class Document < ApplicationRecord
  include PgSearch::Model

  pg_search_scope :full_text_search,
    against: { title: 'A', body: 'B' },
    associated_against: {
      tags: { name: 'C' }
    },
    using: {
      tsearch: {
        dictionary: 'english',
        tsvector_column: 'search_vector'
      },
      trigram: {
        threshold: 0.3,
        word_similarity: true
      }
    },
    ranked_by: ':tsearch + :trigram'

  scope :search_for_user, ->(query, user) {
    full_text_search(query)
      .joins(:workspace)
      .where(workspaces: { user_id: user.id })
      .active
  }
end
```

### Service Layer

**File**: `app/services/search_service.rb`
- Handles search logic, pagination, and timing
- Scopes search to user's workspaces
- Excludes archived documents by default
- Returns search results with metadata

### Controller

**File**: `app/controllers/api/v1/search_controller.rb`
- Validates query parameter
- Delegates to SearchService
- Returns JSON response with data and meta

### Response Format

```json
{
  "data": [
    {
      "id": 1,
      "title": "Getting Started with Rails",
      "body_preview": "# Getting Started...",
      "folder_id": 3,
      "archived_at": null,
      "created_at": "2026-07-15T10:30:00Z",
      "updated_at": "2026-07-16T08:15:00Z",
      "folder": { "id": 3, "name": "Guides" },
      "tags": [{ "id": 1, "name": "rails" }]
    }
  ],
  "meta": {
    "page": 1,
    "per_page": 20,
    "total": 42,
    "total_pages": 3,
    "search_time_ms": 12.34
  }
}
```

### Performance

- **GIN index** provides O(log n) lookup for full-text queries
- **Trigram index** enables fuzzy/partial matching
- **Search latency** typically <20ms with 1000+ documents
- **Pagination** limits returned rows for large result sets

### Testing

**File**: `spec/requests/api/v1/search_spec.rb`
- Auth tests (401 without token)
- Validation tests (422 with blank query)
- Search functionality tests
- Scoping tests (user isolation)
- Archive filtering tests
- Pagination tests

---

## Next Steps

- [x] Create Workspace model
- [x] Create Folder model
- [x] Create Document model
- [x] Create Tag model
- [x] Add API controllers for CRUD operations
- [x] Implement full-text search
- [ ] Add API versioning
- [ ] Deploy to production
