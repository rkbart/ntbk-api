require 'rails_helper'

RSpec.describe 'Api::V1::Search', type: :request do
  let(:user) { create(:user) }
  let(:workspace) { user.workspaces.first }
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
        expect(json_response_meta['total']).to eq(25)
        expect(json_response_meta['total_pages']).to eq(3)
      end
    end

    context 'scoped to current user' do
      let(:other_user) { create(:user) }
      let(:other_workspace) { other_user.workspaces.first }

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

    context 'includes archived when requested' do
      before do
        create(:document, :archived, workspace: workspace,
               title: 'Archived Document', body: 'Archived content')
        get '/api/v1/search', params: { q: 'archived', archived: 'true' }, headers: headers
      end

      it 'includes archived documents' do
        titles = json_response_data.map { |d| d['title'] }
        expect(titles).to include('Archived Document')
      end
    end
  end
end
