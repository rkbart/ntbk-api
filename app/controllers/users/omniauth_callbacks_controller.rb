class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  skip_before_action :verify_authenticity_token, raise: false

  def google_oauth2
    @user = User.from_omniauth(request.env["omniauth.auth"])

    if @user.persisted?
      # Generate JWT token for API response
      token = JwtService.encode(user_id: @user.id)

      # For API mode, we'll redirect with the token
      # In a real app, you might want to handle this differently
      redirect_to "#{ENV.fetch('FRONTEND_URL', 'http://localhost:3001')}/auth/callback?token=#{token}&user_id=#{@user.id}"
    else
      # Handle the error
      session["devise.google_oauth2_data"] = request.env["omniauth.auth"]
      redirect_to "#{ENV.fetch('FRONTEND_URL', 'http://localhost:3001')}/auth/error?message=Could+not+authenticate+you+from+Google+account"
    end
  end

  def failure
    redirect_to "#{ENV.fetch('FRONTEND_URL', 'http://localhost:3001')}/auth/error?message=#{failure_message}"
  end

  private

  def failure_message
    case failure_type
    when :invalid
      "Invalid credentials"
    when :invalid_strategy
      "Invalid authentication strategy"
    else
      "Authentication failed"
    end
  end
end
