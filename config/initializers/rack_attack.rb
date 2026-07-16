class Rack::Attack
  # Throttle file uploads
  throttle('attachments/ip', limit: 10, period: 1.minute) do |req|
    if req.path.match?(%r{/api/v1/workspaces/.+/documents/.+/attachments$}) && req.post?
      req.ip
    end
  end

  # Throttle file size (approximate)
  throttle('attachments/size/ip', limit: 100.megabytes, period: 1.hour) do |req|
    if req.path.match?(%r{/api/v1/workspaces/.+/documents/.+/attachments$}) && req.post?
      req.env['CONTENT_LENGTH']&.to_i
    end
  end
end
