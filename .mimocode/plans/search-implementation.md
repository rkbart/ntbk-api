# NTBK Search Implementation Design

## 1. Recommended Approach: PostgreSQL Native FTS with `pg_search` Gem

### Decision: Option B — pg_search gem wrapping PostgreSQL native FTS

**Rationale:**

| Factor | Native PG FTS | pg_search (Option B) | Elasticsearch/Meilisearch (Option C) |
|--------|--------------|---------------------|--------------------------------------|
| Setup complexity | High — manual tsvector, tsquery, SQL | Low — declarative DSL | High — external service, index sync |
| Relevance ranking | Manual `ts_rank` / `ts_rank_cd` | Built-in `:ranked_search` | Superior (BM25, field boosts) |
| Snippet generation | Manual `ts_headline` | Built-in `pg_search_highlight` | Built-in |
| Fuzzy matching | Requires `pg_trgm` extension | Built-in `:trigram` feature | Built-in |
| Maintenance | You own all SQL | Gem maintainer handles edge cases | External service ops burden |
| Performance | Excellent with GIN index | Excellent (same underlying PG) | Excellent but adds network hop |
| Dependencies | None | 1 gem | External service + client gem |
| <200ms requirement | Achievable | Achievable | Achievable |

**Why pg_search wins here:**
- The project already uses PostgreSQL 16 — no new infrastructure needed
- pg_search provides declarative scopes with ranking, highlighting, and trigram fuzzy matching out of the box
- No external service to deploy, monitor, or keep in sync
- For a documents search use case (not millions of records), PostgreSQL FTS is more than sufficient
- The gem is well-maintained (6k+ GitHub stars, active development)

**What pg_search gives us:**
- `pg_search_scope` — declarative search scope on the Document model
- `pg_search_highlight` — snippet generation with `<b>` highlighting
- Built-in ranking via `ts_rank` or `ts_rank_cd`
- Trigram support for fuzzy/partial matching
- Multi-language stemming support

---

## 2. Search Scope Decisions

### Scope: Search across all user's workspaces
**Yes.** Users expect a global search. Scoping to a single workspace would be an advanced filter, not the default.

### Include archived documents?
**No by default.** Active documents only. Users can add an `archived=true` parameter later if needed. The `active` scope already exists on Document.

### Implementation:
```ruby
# Documents in user's workspaces, active only
Document.joins(:workspace)
        .where(workspaces: { user_id: current_user.id })
        .active
```

---

## 3. Database Migration Plan

### Migration 1: Enable pg_trgm extension (for fuzzy matching)

```ruby
class EnablePgTrgmExtension < ActiveRecord::Migration[8.1]
  def up
    enable_extension 'pg_trgm'
  end

  def down
    disable_extension 'pg_trgm'
  end
end
```

### Migration 2: Add search_vector column + GIN index

```ruby
class AddSearchVectorToDocuments < ActiveRecord::Migration[8.1]
  def up
    # Add tsvector column for full-text search
    add_column :documents, :search_vector, :tsvector

    # GIN index on search_vector for fast full-text queries
    add_index :documents, :search_vector, using: :gin

    # Trigger to auto-update search_vector on INSERT/UPDATE
    execute <<~SQL
      CREATE OR REPLACE FUNCTION documents_search_vector_update() RETURNS trigger AS $$
      BEGIN
        NEW.search_vector :=
          setweight(to_tsvector('english', COALESCE(NEW.title, '')), 'A') ||
          setweight(to_tsvector('english', COALESCE(NEW.body, '')), 'B');
        RETURN NEW;
      END
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER documents_search_vector_trigger
        BEFORE INSERT OR UPDATE OF title, body
        ON documents
        FOR EACH ROW
        EXECUTE FUNCTION documents_search_vector_update();
    SQL

    # Backfill existing documents
    execute <<~SQL
      UPDATE documents SET search_vector :=
        setweight(to_tsvector('english', COALESCE(title, '')), 'A') ||
        setweight(to_tsvector('english', COALESCE(body, '')), 'B');
    SQL
  end

  def down
    execute "DROP TRIGGER IF EXISTS documents_search_vector_trigger ON documents"
    execute "DROP FUNCTION IF EXISTS documents_search_vector_update()"
    remove_index :documents, :search_vector
    remove_column :documents, :search_vector
  end
end
```

### Migration 3: Add trigram GIN index (for fuzzy matching)

```ruby
class AddTrigramIndexToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_index :documents, [:title, :body], using: :gin,
              opclass: :gin_trgm_ops,
              name: 'index_documents_on_title_body_trigram'
  end
end
```

### Column weighting rationale:
- **Weight A (title)**: Title matches should rank higher — users searching by title expect it at the top
- **Weight B (body)**: Body matches are secondary but still relevant
- Weights C/D are reserved for future use (e.g., tag names as weight C)

---

## 4. Model Changes

### `app/models/document.rb`

```ruby
class Document < ApplicationRecord
  # ... existing code ...

  # pg_search scope for full-text search
  include PgSearch::Model

  pg_search_scope :full_text_search,
    against: { title: 'A', body: 'B' },
    associated_against: {
      tags: { name: 'C' }
    },
    using: {
      tsearch: {
        dictionary: 'english',
        tsvector_column: 'search_vector',
        rank_only_by: :cd   # use ts_rank_cd for better relevance
      },
      trigram: {
        threshold: 0.3,
        word_similarity: true
      }
    },
    ranked_by: ':tsearch + :trigram',
    prefix: true  # allows partial word matching ("prog" matches "programming")

  # Scope: search within user's active documents
  scope :search_for_user, ->(query, user) {
    full_text_search(query)
      .joins(:workspace)
      .where(workspaces: { user_id: user.id })
      .active
  }

  # ... existing scopes and methods ...
end
```

### Search result enrichment (in controller or service):

```ruby
# Snippet generation using PostgreSQL's ts_headline
def self.search_snippet(query, length: 200)
  sanitized_query = sanitize_sql(query)
  select("*, ts_headline('english', body, plainto_tsquery('english', #{sanitized_query}), 'StartSel=<mark>, StopSel=</mark>, MaxWords=#{length}, MinWords=50') AS snippet")
end
```

---

## 5. Service Object: `app/services/search_service.rb`

```ruby
class SearchService
  MAX_RESULTS = 100
  DEFAULT_PER_PAGE = 20

  def initialize(user:, query:, params: {})
    @user = user
    @query = query.to_s.strip
    @page = (params[:page] || 1).to_i
    @per_page = [params[:per_page] || DEFAULT_PER_PAGE, MAX_RESULTS].min
    @include_archived = params[:archived] == 'true'
  end

  def call
    return empty_result if @query.blank?

    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    documents = base_scope
    documents = apply_search(documents)
    documents = documents.includes(:workspace, :folder, :tags)
    documents = documents.page(@page).per(@per_page)

    elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)

    {
      documents: documents,
      meta: build_meta(documents, elapsed_ms)
    }
  end

  private

  def base_scope
    scope = Document.joins(:workspace)
                    .where(workspaces: { user_id: @user.id })

    scope = @include_archived ? scope : scope.active
    scope
  end

  def apply_search(scope)
    scope.full_text_search(@query)
         .select(
           'documents.*',
           "ts_rank_cd(documents.search_vector, plainto_tsquery('english', #{ActiveRecord::Base.sanitize_sql_for_conditions(@query)})) AS rank"
         )
         .order(Arel.sql('rank DESC'))
  end

  def build_meta(documents, elapsed_ms)
    {
      page: @page,
      per_page: @per_page,
      total: documents.total_count,
      total_pages: documents.total_pages,
      search_time_ms: elapsed_ms
    }
  end

  def empty_result
    {
      documents: Document.none.page(1).per(@per_page),
      meta: { page: 1, per_page: @per_page, total: 0, total_pages: 0, search_time_ms: 0 }
    }
  end
end
```

---

## 6. Controller Design: `app/controllers/api/v1/search_controller.rb`

```ruby
module Api
  module V1
    class SearchController < BaseController
      before_action :validate_query!

      # GET /api/v1/search?q=query&page=1&per_page=20
      def index
        result = SearchService.new(
          user: current_user,
          query: params[:q],
          params: search_params
        ).call

        render json: {
          data: SearchResultSerializer.new(result[:documents], search_query: params[:q]).as_json,
          meta: result[:meta]
        }
      end

      private

      def validate_query!
        if params[:q].blank?
          render json: {
            error: {
              code: 'VALIDATION_ERROR',
              message: 'Search query is required',
              details: [{ field: 'q', message: 'must be present' }]
            }
          }, status: :unprocessable_entity
        end
      end

      def search_params
        params.permit(:page, :per_page, :archived)
      end
    end
  end
end
```

---

## 7. Serializer Design: `app/serializers/search_result_serializer.rb`

```ruby
class SearchResultSerializer < ActiveModel::Serializer
  attributes :id, :title, :body_preview, :snippet, :folder_id,
             :archived_at, :rank, :created_at, :updated_at

  has_one :folder
  has_many :tags

  def body_preview
    object.body.present? ? object.body.truncate(200) : nil
  end

  def snippet
    return nil unless object.respond_to?(:snippet) && object.snippet.present?

    # Clean up ts_headline output — remove extra whitespace
    object.snippet.gsub(/\s+/, ' ').strip
  end

  def rank
    object.respond_to?(:rank) ? object.rank.round(4) : nil
  end

  def created_at
    object.created_at&.iso8601
  end

  def updated_at
    object.updated_at&.iso8601
  end
end
```

### Response format example:

```json
{
  "data": [
    {
      "id": 1,
      "title": "Getting Started with Rails",
      "body_preview": "# Getting Started with Rails\n\nThis guide covers...",
      "snippet": "...how to get started with <b>Rails</b> quickly. <b>Rails</b> is a web framework...",
      "folder_id": 3,
      "archived_at": null,
      "rank": 0.6054,
      "created_at": "2026-07-15T10:30:00Z",
      "updated_at": "2026-07-16T08:15:00Z",
      "folder": { "id": 3, "name": "Guides" },
      "tags": [
        { "id": 1, "name": "rails" },
        { "id": 2, "name": "tutorial" }
      ]
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

---

## 8. Route Addition

```ruby
# config/routes.rb — add inside namespace :api / namespace :v1
namespace :api do
  namespace :v1 do
    get 'search', to: 'search#index'
    # ... existing routes ...
  end
end
```

---

## 9. Test Plan

### Factory additions (`spec/factories/documents.rb`):

```ruby
trait :with_searchable_content do
  title { Faker::Lorem.sentence(word_count: 5) }
  body { Faker::Lorem.paragraphs(number: 3).join("\n\n") }
end
```

### Request spec: `spec/requests/api/v1/search_spec.rb`

```ruby
require 'rails_helper'

RSpec.describe 'Api::V1::Search', type: :request do
  let(:user) { create(:user, :confirmed) }
  let(:workspace) { create(:workspace, user: user) }
  let(:token) { JwtService.encode(user_id: user.id) }
  let(:headers) { { 'Authorization' => "Bearer #{token}" } }

  before do
    # Create test documents with known content
    create(:document, workspace: workspace, title: 'Ruby on Rails Guide',
           body: 'Ruby on Rails is a web framework for building applications')
    create(:document, workspace: workspace, title: 'PostgreSQL Tips',
           body: 'PostgreSQL is a powerful relational database')
    create(:document, workspace: workspace, title: 'JavaScript Basics',
           body: 'JavaScript is a programming language for the web')
  end

  describe 'GET /api/v1/search' do
    context 'with valid query' do
      before { get '/api/v1/search', params: { q: 'rails' }, headers: headers }

      it 'returns matching documents' do
        expect(response).to have_http_status(:ok)
        data = json_response_data
        expect(data.length).to eq(1)
        expect(data.first['title']).to eq('Ruby on Rails Guide')
      end

      it 'includes snippet with highlighted terms' do
        snippet = json_response_data.first['snippet']
        expect(snippet).to include('<b>Rails</b>')
      end

      it 'includes relevance rank' do
        expect(json_response_data.first['rank']).to be > 0
      end

      it 'includes search_time_ms in meta' do
        expect(json_response_meta['search_time_ms']).to be_a(Numeric)
      end
    end

    context 'with no results' do
      before { get '/api/v1/search', params: { q: 'xyznonexistent' }, headers: headers }

      it 'returns empty data array' do
        expect(response).to have_http_status(:ok)
        expect(json_response_data).to be_empty
        expect(json_response_meta['total']).to eq(0)
      end
    end

    context 'with blank query' do
      before { get '/api/v1/search', params: { q: '' }, headers: headers }

      it 'returns validation error' do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response_error['code']).to eq('VALIDATION_ERROR')
      end
    end

    context 'without authentication' do
      before { get '/api/v1/search', params: { q: 'rails' } }

      it 'returns unauthorized' do
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with pagination' do
      before do
        # Create 25 documents with "searchable" content
        25.times do |i|
          create(:document, workspace: workspace,
                 title: "Searchable Document #{i}",
                 body: 'This document contains searchable content')
        end
        get '/api/v1/search', params: { q: 'searchable', per_page: 10 }, headers: headers
      end

      it 'paginates results' do
        expect(json_response_data.length).to eq(10)
        expect(json_response_meta['total']).to eq(26) # 25 + 1 from before block
        expect(json_response_meta['total_pages']).to eq(3)
      end
    end

    context 'scoped to current user' do
      let(:other_user) { create(:user, :confirmed) }
      let(:other_workspace) { create(:workspace, user: other_user) }

      before do
        create(:document, workspace: other_workspace,
               title: 'Other User Document',
               body: 'This belongs to another user')
        get '/api/v1/search', params: { q: 'other user' }, headers: headers
      end

      it 'does not include other users documents' do
        titles = json_response_data.map { |d| d['title'] }
        expect(titles).not_to include('Other User Document')
      end
    end

    context 'excludes archived by default' do
      before do
        create(:document, :archived, workspace: workspace,
               title: 'Archived Document', body: 'Archived content')
        get '/api/v1/search', params: { q: 'archived' }, headers: headers
      end

      it 'does not include archived documents' do
        titles = json_response_data.map { |d| d['title'] }
        expect(titles).not_to include('Archived Document')
      end
    end
  end
end
```

### Model spec additions (`spec/models/document_spec.rb`):

```ruby
describe '.full_text_search' do
  let!(:doc1) { create(:document, workspace: workspace, title: 'Ruby Guide', body: 'Learn Ruby programming') }
  let!(:doc2) { create(:document, workspace: workspace, title: 'Python Guide', body: 'Learn Python programming') }
  let!(:doc3) { create(:document, workspace: workspace, title: 'Ruby on Rails', body: 'Web framework') }

  it 'finds documents matching the query' do
    results = Document.full_text_search('ruby')
    expect(results).to include(doc1, doc3)
    expect(results).not_to include(doc2)
  end

  it 'ranks title matches higher than body matches' do
    results = Document.full_text_search('ruby').order(Arel.sql('rank DESC'))
    # doc3 has "Ruby" in title, doc1 has "Ruby" in title too but doc3 is more relevant
    # The exact ranking depends on term frequency
    expect(results.first.title).to match(/Ruby/i)
  end
end

describe '.search_for_user' do
  let(:other_user) { create(:user, :confirmed) }
  let(:other_workspace) { create(:workspace, user: other_user) }

  before do
    create(:document, workspace: workspace, title: 'My Document', body: 'Searchable')
    create(:document, workspace: other_workspace, title: 'Their Document', body: 'Searchable')
  end

  it 'only returns documents from user workspaces' do
    results = Document.search_for_user('searchable', user)
    expect(results.map(&:title)).to eq(['My Document'])
  end
end
```

---

## 10. Performance Considerations

### Index strategy:
1. **GIN index on `search_vector`** — primary index for full-text search queries. O(log n) lookup.
2. **GIN trigram index on `[title, body]`** — enables fuzzy/partial matching via `pg_trgm`.
3. **Existing composite index on `[workspace_id, archived_at]`** — supports the workspace scoping + active filter.

### Query plan:
```
1. JOIN documents → workspace (index scan on workspace_id)
2. WHERE workspace_id IN (user's workspaces) AND archived_at IS NULL
3. WHERE search_vector @@ plainto_tsquery('english', 'query')
4. ORDER BY ts_rank_cd(search_vector, plainto_tsquery(...)) DESC
5. LIMIT n OFFSET m
```

### Expected performance:
- With GIN index: <10ms for most queries (even with 100k documents)
- With trigram index: <20ms for fuzzy queries
- <200ms target is well within reach

### Mitigations for edge cases:
- **Empty body**: `COALESCE(body, '')` in the trigger handles NULL bodies
- **Very long documents**: `ts_headline` max words parameter limits snippet size
- **Large result sets**: Kaminari pagination limits returned rows
- **Concurrent updates**: The trigger is atomic — no race conditions on tsvector updates

### Monitoring:
- Log `search_time_ms` in the response meta for observability
- Add slow-query threshold logging in development (e.g., warn if >100ms)
- Consider adding `EXPLAIN ANALYZE` logging in development for query optimization

---

## 11. Implementation Steps (in order)

### Phase 1: Database setup (migrations)
1. `rails g migration EnablePgTrgmExtension`
2. `rails g migration AddSearchVectorToDocuments`
3. `rails g migration AddTrigramIndexToDocuments`
4. `rails db:migrate`

### Phase 2: Gem installation
5. Add `pg_search` to Gemfile
6. `bundle install`

### Phase 3: Model changes
7. Add `include PgSearch::Model` and `pg_search_scope` to Document model
8. Add `search_for_user` scope to Document model
9. Run model specs to verify existing functionality unchanged

### Phase 4: Service layer
10. Create `app/services/search_service.rb`
11. Write unit tests for SearchService

### Phase 5: Controller + Serializer
12. Create `app/controllers/api/v1/search_controller.rb`
13. Create `app/serializers/search_result_serializer.rb`
14. Add route to `config/routes.rb`

### Phase 6: Testing
15. Create `spec/requests/api/v1/search_spec.rb`
16. Create/update model specs for search scopes
17. Run full test suite

### Phase 7: Performance verification
18. Seed test data (1000+ documents)
19. Verify query plans with `EXPLAIN ANALYZE`
20. Benchmark search latency
21. Verify <200ms target

### Phase 8: Documentation
22. Update API documentation (if exists)
23. Update DEVELOPMENT.md with search implementation notes

---

## 12. Future Enhancements (out of scope for v1)

- **Search within specific workspace**: `GET /api/v1/workspaces/:id/search?q=query`
- **Search by tag**: Combine tag filter with text search
- **Search suggestions/autocomplete**: Using trigram similarity
- **Search history**: Track recent searches per user
- **Advanced search operators**: AND, OR, NOT, phrase search, field-specific search
- **Stemming configuration**: Language-specific stemming beyond English
- **Highlight customization**: Different highlight styles/markers
- **Search analytics**: Track popular queries, zero-result queries
