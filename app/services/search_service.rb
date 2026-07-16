class SearchService
  MAX_RESULTS = 100
  DEFAULT_PER_PAGE = 20

  def initialize(user:, query:, params: {})
    @user = user
    @query = query.to_s.strip
    @page = (params[:page] || 1).to_i
    @per_page = [ (params[:per_page] || DEFAULT_PER_PAGE).to_i, MAX_RESULTS ].min
    @include_archived = params[:archived] == "true"
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
