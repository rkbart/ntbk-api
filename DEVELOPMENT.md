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

  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :password, length: { minimum: 6 }, if: :password_required?

  before_save :downcase_email

  private

  def downcase_email
    self.email = email.downcase if email.present?
  end

  def password_required?
    new_record? || password.present?
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
│   └── users.rb
├── models/
│   └── user_spec.rb
└── requests/
    └── api/v1/
        └── auth_spec.rb
```

### Factory
**File**: `spec/factories/users.rb`
```ruby
FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    password_confirmation { "password123" }

    trait :confirmed do
      confirmed_at { Time.current }
    end
  end
end
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

  def created_at
    object.created_at&.iso8601
  end

  def updated_at
    object.updated_at&.iso8601
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

## Test Coverage

### Model Specs
- `spec/models/user_spec.rb` - 11 examples

### Request Specs
- `spec/requests/api/v1/auth_spec.rb` - 13 examples

**Total**: 24 examples, 0 failures

---

## File Structure

```
ntbk/
├── app/
│   ├── controllers/
│   │   └── api/v1/
│   │       ├── base_controller.rb
│   │       └── auth_controller.rb
│   ├── models/
│   │   └── user.rb
│   ├── serializers/
│   │   └── user_serializer.rb
│   └── services/
│       └── jwt_service.rb
├── config/
│   ├── initializers/
│   │   ├── cors.rb
│   │   └── devise.rb
│   └── routes.rb
├── db/
│   └── migrate/
│       └── devise_create_users.rb
├── spec/
│   ├── factories/
│   │   └── users.rb
│   ├── models/
│   │   └── user_spec.rb
│   ├── requests/api/v1/
│   │   └── auth_spec.rb
│   └── support/
│       └── api_helpers.rb
├── .github/workflows/
│   └── ci.yml
└── Gemfile
```

---

## Next Steps

- [ ] Create Workspace model
- [ ] Create Folder model
- [ ] Create Document model
- [ ] Create Tag model
- [ ] Implement full-text search
- [ ] Add API versioning
- [ ] Deploy to production
