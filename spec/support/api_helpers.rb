# API helper methods for request specs
module ApiHelpers
  def json_response
    JSON.parse(response.body)
  end

  def json_response_data
    json_response['data']
  end

  def json_response_meta
    json_response['meta']
  end

  def json_response_error
    json_response['error']
  end

  def auth_headers(user)
    token = JwtService.encode(user_id: user.id)
    { 'Authorization' => "Bearer #{token}" }
  end
end

RSpec.configure do |config|
  config.include ApiHelpers, type: :request
end
