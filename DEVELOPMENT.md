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
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: [:google_oauth2]

  # Associations
  has_many :workspaces, dependent: :destroy
  has_many :tags, dependent: :destroy
  has_many :conversations, dependent: :destroy
  has_many :oauth_identities, dependent: :destroy

  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :password, length: { minimum: 6 }, if: :password_required?

  before_save :downcase_email
  after_create :create_default_workspace

  # ... (see full model in app/models/user.rb)
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

## Google OAuth Setup

### Installation
```bash
# Add to Gemfile
echo 'gem "omniauth-google-oauth2"' >> Gemfile
bundle install
```

### Google Cloud Console Setup
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing
3. Go to **APIs & Services > Credentials**
4. Click **Create Credentials > OAuth client ID**
5. Set **Application type** to **Web application**
6. Add **Authorized redirect URIs**:
   - `http://localhost:3000/users/auth/google_oauth2/callback`
7. Copy the **Client ID** and **Client Secret**

### Environment Variables
Add to `.env`:
```bash
GOOGLE_CLIENT_ID=your_client_id_here
GOOGLE_CLIENT_SECRET=your_client_secret_here
FRONTEND_URL=http://localhost:5173
```

### Devise Configuration
**File**: `config/initializers/devise.rb`
```ruby
if ENV["GOOGLE_CLIENT_ID"].present? && ENV["GOOGLE_CLIENT_SECRET"].present?
  config.omniauth :google_oauth2,
                  ENV.fetch("GOOGLE_CLIENT_ID"),
                  ENV.fetch("GOOGLE_CLIENT_SECRET"),
                  scope: "email,profile",
                  info_fields: "email,name,picture"
end

# Allow GET for OmniAuth authorize route (required for SPA redirect flow)
OmniAuth.config.allowed_request_methods = [:get, :post]
OmniAuth.config.silence_get_warning = true
```

### Controller
**File**: `app/controllers/users/omniauth_callbacks_controller.rb`
```ruby
class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  skip_before_action :verify_authenticity_token, raise: false

  def google_oauth2
    @user = User.from_omniauth(request.env["omniauth.auth"])

    if @user.persisted?
      token = JwtService.encode(user_id: @user.id)
      redirect_to "#{ENV.fetch('FRONTEND_URL', 'http://localhost:5173')}/auth/callback?token=#{token}&user_id=#{@user.id}"
    else
      redirect_to "#{ENV.fetch('FRONTEND_URL', 'http://localhost:5173')}/auth/error?message=Could+not+authenticate+you+from+Google+account"
    end
  end

  def failure
    redirect_to "#{ENV.fetch('FRONTEND_URL', 'http://localhost:5173')}/auth/error?message=Authentication+failed"
  end
end
```

### Model
**File**: `app/models/user.rb`
```ruby
def self.from_omniauth(auth)
  identity = OauthIdentity.find_or_initialize_by(
    provider: auth.provider,
    uid: auth.uid
  )

  if identity.user.present?
    identity.user
  else
    user = User.find_by(email: auth.info.email)
    if user
      identity.user = user
      identity.save!
      user
    else
      user = User.create!(
        email: auth.info.email,
        password: Devise.friendly_token[0, 20]
      )
      identity.user = user
      identity.save!
      user
    end
  end
end
```

### OAuth Flow
1. Frontend redirects to `GET /users/auth/google_oauth2`
2. Devise redirects to Google's OAuth consent screen
3. After authorization, Google redirects to callback URL
4. Callback creates/finds user and redirects to frontend with JWT token
5. Frontend stores token and authenticates via JWT

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

### Attachments Controller
**File**: `app/controllers/api/v1/attachments_controller.rb`

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| GET | /api/v1/workspaces/:workspace_id/documents/:document_id/attachments | List attachments | Yes |
| GET | /api/v1/workspaces/:workspace_id/documents/:document_id/attachments/:id | Get attachment | Yes |
| POST | /api/v1/workspaces/:workspace_id/documents/:document_id/attachments | Upload file | Yes |
| DELETE | /api/v1/workspaces/:workspace_id/documents/:document_id/attachments/:id | Delete attachment | Yes |
| GET | /api/v1/workspaces/:workspace_id/documents/:document_id/attachments/:id/download | Download file | Yes |
| GET | /api/v1/workspaces/:workspace_id/documents/:document_id/attachments/:id/preview | Get preview | Yes |

---

## Test Coverage

### Model Specs
- `spec/models/user_spec.rb` - 11 examples
- `spec/models/workspace_spec.rb` - 10 examples
- `spec/models/folder_spec.rb` - 12 examples
- `spec/models/document_spec.rb` - 14 examples
- `spec/models/tag_spec.rb` - 10 examples
- `spec/models/document_tag_spec.rb` - 6 examples
- `spec/models/attachment_spec.rb` - 11 examples

### Request Specs
- `spec/requests/api/v1/auth_spec.rb` - 13 examples
- `spec/requests/api/v1/workspaces_spec.rb` - 7 examples
- `spec/requests/api/v1/folders_spec.rb` - 7 examples
- `spec/requests/api/v1/documents_spec.rb` - 11 examples
- `spec/requests/api/v1/tags_spec.rb` - 4 examples
- `spec/requests/api/v1/search_spec.rb` - 9 examples
- `spec/requests/api/v1/attachments_spec.rb` - 4 examples

**Total**: 131 examples, 0 failures

---

## File Structure

```
ntbk-api/
├── app/
│   ├── controllers/
│   │   └── api/v1/
│   │       ├── base_controller.rb
│   │       ├── auth_controller.rb
│   │       ├── workspaces_controller.rb
│   │       ├── folders_controller.rb
│   │       ├── documents_controller.rb
│   │       ├── tags_controller.rb
│   │       ├── search_controller.rb
│   │       └── attachments_controller.rb
│   │   └── attachments/
│   │       ├── download_controller.rb
│   │       └── preview_controller.rb
│   │   └── ai/
│   │       ├── base_controller.rb
│   │       ├── embeddings_controller.rb
│   │       ├── chat_controller.rb
│   │       └── summaries_controller.rb
│   ├── models/
│   │   ├── user.rb
│   │   ├── workspace.rb
│   │   ├── folder.rb
│   │   ├── document.rb
│   │   ├── tag.rb
│   │   ├── document_tag.rb
│   │   ├── attachment.rb
│   │   ├── conversation.rb
│   │   └── message.rb
│   ├── serializers/
│   │   ├── user_serializer.rb
│   │   ├── workspace_serializer.rb
│   │   ├── folder_serializer.rb
│   │   ├── document_serializer.rb
│   │   ├── tag_serializer.rb
│   │   ├── search_result_serializer.rb
│   │   ├── attachment_serializer.rb
│   │   ├── conversation_serializer.rb
│   │   └── message_serializer.rb
│   ├── services/
│   │   ├── jwt_service.rb
│   │   ├── search_service.rb
│   │   ├── ollama_client.rb
│   │   ├── embedding_service.rb
│   │   ├── summary_service.rb
│   │   └── chat_service.rb
│   └── jobs/
│       ├── attachments/
│       │   ├── thumbnail_generator_job.rb
│       │   └── metadata_extractor_job.rb
│       ├── embedding_job.rb
│       ├── summary_job.rb
│       └── document_embedding_job.rb
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
│   │   ├── document_tags.rb
│   │   └── attachments.rb
│   ├── models/
│   │   ├── user_spec.rb
│   │   ├── workspace_spec.rb
│   │   ├── folder_spec.rb
│   │   ├── document_spec.rb
│   │   ├── tag_spec.rb
│   │   ├── document_tag_spec.rb
│   │   └── attachment_spec.rb
│   ├── requests/api/v1/
│   │   ├── auth_spec.rb
│   │   ├── workspaces_spec.rb
│   │   ├── folders_spec.rb
│   │   ├── documents_spec.rb
│   │   ├── tags_spec.rb
│   │   ├── search_spec.rb
│   │   └── attachments_spec.rb
│   └── support/
│       └── api_helpers.rb
├── .github/workflows/
│   └── ci.yml
├── DEVELOPMENT.md
└── Gemfile
```

---

## File Uploads Implementation (Milestone 4)

### Installation
```bash
# Add rack-attack to Gemfile
echo 'gem "rack-attack"' >> Gemfile
bundle install

# Install Active Storage migrations
bin/rails active_storage:install
```

### Database Setup

**Tables**:
- `active_storage_blobs` - File metadata (Active Storage)
- `active_storage_attachments` - Join table (Active Storage)
- `attachments` - Custom attachment metadata

**Columns on attachments**:
- `document_id` (references, not null, foreign key)
- `filename` (string, not null)
- `content_type` (string, not null)
- `file_size` (bigint, not null)
- `metadata` (jsonb, default: {})
- `preview_state` (string, default: 'pending')

**Indexes**:
- `document_id` - For efficient document lookups
- `content_type` - For type filtering
- `preview_state` - For preview status queries

### Model Changes

**File**: `app/models/attachment.rb`
```ruby
class Attachment < ApplicationRecord
  MAX_FILE_SIZE = 50.megabytes
  ALLOWED_CONTENT_TYPES = %w[
    image/jpeg image/png image/gif image/webp image/svg+xml
    application/pdf
    text/plain text/markdown text/csv text/html text/css text/javascript
    application/json application/zip application/gzip
  ].freeze

  belongs_to :document, counter_cache: :attachments_count
  has_one_attached :file
  has_one_attached :thumbnail

  validates :filename, presence: true, length: { maximum: 255 }
  validates :content_type, presence: true, inclusion: { in: ALLOWED_CONTENT_TYPES }
  validates :file_size, presence: true, numericality: { less_than_or_equal_to: MAX_FILE_SIZE }
  validate :file_present

  enum :preview_state, { pending: 'pending', processing: 'processing', completed: 'completed', failed: 'failed' }, prefix: :preview

  scope :images, -> { where("content_type LIKE ?", "image/%") }
  scope :documents, -> { where("content_type LIKE ? OR content_type LIKE ?", "application/pdf", "text/%") }
end
```

**File**: `app/models/document.rb` (additions)
```ruby
has_many :attachments, dependent: :destroy

def image_attachments
  attachments.images
end

def attachments_size_sum
  attachments.sum(:file_size)
end
```

### API Endpoints

**Attachments**:
- `GET /api/v1/workspaces/:workspace_id/documents/:document_id/attachments` - List
- `POST /api/v1/workspaces/:workspace_id/documents/:document_id/attachments` - Upload
- `GET /api/v1/workspaces/:workspace_id/documents/:document_id/attachments/:id` - Show
- `DELETE /api/v1/workspaces/:workspace_id/documents/:document_id/attachments/:id` - Delete
- `GET /api/v1/workspaces/:workspace_id/documents/:document_id/attachments/:id/download` - Download
- `GET /api/v1/workspaces/:workspace_id/documents/:document_id/attachments/:id/preview` - Preview

### File Size Limits

| Type | Limit | Rationale |
|------|-------|-----------|
| Images | 10 MB | Reasonable for photos/screenshots |
| PDFs | 50 MB | Documents can be large |
| Text | 1 MB | Text files should be small |
| Archives | 50 MB | Compressed files |

### Preview Strategy

| File Type | Preview | Thumbnail |
|-----------|---------|-----------|
| Images | Dimensions + original URL | 300x300 resize |
| PDFs | Page count + first page | First page as PNG |
| Text | First 1000 chars | None |

### Security Measures

- **Content-type allowlist**: Only approved file types
- **File size limits**: Per-type limits enforced
- **Access control**: Attachments scoped to user's workspaces
- **Rate limiting**: 10 uploads/minute per IP (via rack-attack)

### Background Jobs

- `Attachments::ThumbnailGeneratorJob` - Generates thumbnails for images/PDFs
- `Attachments::MetadataExtractorJob` - Extracts metadata (dimensions, checksum, etc.)

---

## AI Features Implementation (Milestone 5)

### Overview

NTBK integrates with Ollama for local AI inference, providing:
- **Embeddings** - Document embeddings for semantic search via pgvector
- **Chat** - Conversational AI interface with document context
- **Summaries** - Auto-generate document summaries

### Installation

```bash
# Install Ollama (if not already installed)
curl -fsSL https://ollama.com/install.sh | sh

# Pull required models
ollama pull nomic-embed-text  # For embeddings (768 dimensions)
ollama pull llama3:8b         # For chat and summaries

# Add neighbor gem to Gemfile
echo 'gem "neighbor"' >> Gemfile
bundle install

# Install pgvector extension (Arch Linux)
sudo pacman -S pgvector

# Run migrations
bin/rails db:migrate
```

### Configuration

**Environment Variables** (`.env.example`):
```bash
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_EMBEDDING_MODEL=nomic-embed-text
OLLAMA_CHAT_MODEL=llama3:8b
OLLAMA_TIMEOUT=60
OLLAMA_VERIFY_ON_BOOT=true
```

**Initializer**: `config/initializers/ollama.rb`

### Database Schema

**New Extensions**:
- `pgvector` - Vector similarity search

**New Columns on documents**:
- `embedding` (vector, 768 dimensions) - Document embedding vector
- `summary` (text) - AI-generated summary
- `summary_generated_at` (datetime) - When summary was generated

**New Tables**:
- `conversations` - Chat conversation history
- `messages` - Individual chat messages with role (user/assistant/system)

### Models

**Document** (additions):
```ruby
has_neighbors :embedding

def needs_summary?
  summary.nil? || updated_at > summary_generated_at
end

def embedding_text
  [title, body].compact.join("\n\n").truncate(2000, separator: " ")
end
```

**Conversation**:
- `belongs_to :user`
- `has_many :messages`
- `scope :recent` - Orders by last_message_at

**Message**:
- `belongs_to :conversation`
- `validates :role, inclusion: %w[user assistant system]`
- `scope :chronological` - Orders by created_at

### Services

**OllamaClient** (`app/services/ollama_client.rb`):
- `embed(text)` - Generate embedding vector
- `chat(messages, options)` - Generate chat completion
- `chat_stream(messages, options, &block)` - Streaming chat
- `health_check` - Verify Ollama is running

**EmbeddingService** (`app/services/embedding_service.rb`):
- `embed_document(document)` - Generate embedding for document
- `embed_documents(documents)` - Batch embedding generation
- `search(query, workspace:, limit:, threshold:)` - Semantic search
- `similar_documents(document, limit:)` - Find similar documents

**SummaryService** (`app/services/summary_service.rb`):
- `generate_summary(document)` - Generate summary for document
- `generate_summaries(documents)` - Batch summary generation

**ChatService** (`app/services/chat_service.rb`):
- `send_message(content, document_ids:)` - Send message and get response
- `send_message_stream(content, document_ids:, &block)` - Streaming response

### API Endpoints

**Embeddings**:
- `POST /api/v1/ai/embeddings` - Generate embedding for text
- `POST /api/v1/ai/embeddings/search` - Semantic search in workspace
- `POST /api/v1/ai/embeddings/similar/:id` - Find similar documents
- `POST /api/v1/ai/embeddings/generate/:id` - Generate embedding for document
- `POST /api/v1/ai/embeddings/generate_workspace/:id` - Generate all embeddings

**Chat**:
- `GET /api/v1/ai/conversations` - List conversations
- `POST /api/v1/ai/conversations` - Create conversation
- `GET /api/v1/ai/conversations/:id` - Get conversation with messages
- `DELETE /api/v1/ai/conversations/:id` - Delete conversation
- `POST /api/v1/ai/chat` - Send chat message
- `POST /api/v1/ai/chat/stream` - Send chat message (SSE streaming)

**Summaries**:
- `GET /api/v1/workspaces/:id/documents/:id/summary` - Get summary
- `POST /api/v1/workspaces/:id/documents/:id/summary` - Generate summary
- `POST /api/v1/ai/summaries/generate_workspace/:id` - Generate all summaries

### Background Jobs

- `EmbeddingJob` - Generate embeddings for workspace documents
- `SummaryJob` - Generate summaries for workspace documents
- `DocumentEmbeddingJob` - Generate embedding for single document

### Testing

**Prerequisites**:
- Ollama running locally
- Models pulled: `nomic-embed-text`, `llama3:8b`

**Run AI-specific tests**:
```bash
bundle exec rspec spec/models/conversation_spec.rb
bundle exec rspec spec/models/message_spec.rb
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
      "workspace_id": 1,
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

---

# User Settings Implementation (Milestone 6)

## Overview

Added user settings page with profile management, password change, and OAuth user handling.

## Database Migrations

### Add name to users
```ruby
class AddNameToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :name, :string
  end
end
```

### Add password_set_by_user to users
```ruby
class AddPasswordSetByUserToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :password_set_by_user, :boolean, default: false, null: false
  end
end
```

## Backend Changes

### User Model
- Added `has_password?` method that checks `password_set_by_user?`
- Updated `from_omniauth` to save Google profile name

### SettingsController
- `GET /api/v1/settings/profile` — Returns user profile with `has_password` and `oauth_providers`
- `PATCH /api/v1/settings/profile` — Updates name and email
- `PATCH /api/v1/settings/password` — Changes/sets password
  - Email/password users: requires current password
  - OAuth users: no current password required

### Routes
```ruby
get "settings/profile", to: "settings#profile"
patch "settings/profile", to: "settings#update_profile"
patch "settings/password", to: "settings#update_password"
```

### UserSerializer
- Added `name` attribute to serialized user data

## Key Design Decisions

1. **OAuth password handling**: Use `password_set_by_user` flag to distinguish OAuth vs email/password users
2. **Email disabled in settings**: Email is tied to account, cannot be changed
3. **Name display**: Dashboard shows name instead of email in "Signed in as"

## Testing
- 131+ tests passing
- Added settings controller tests for profile and password updates
