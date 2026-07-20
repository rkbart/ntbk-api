class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  skip_before_action :verify_authenticity_token, raise: false

  def google_oauth2
    @user = User.from_omniauth(request.env["omniauth.auth"])

    if @user.persisted?
      token = JwtService.encode(user_id: @user.id)
      redirect_to "#{ENV.fetch('FRONTEND_URL', 'http://localhost:5173')}/auth/callback?token=#{token}&user_id=#{@user.id}"
    else
      session["devise.google_oauth2_data"] = request.env["omniauth.auth"]
      redirect_to "#{ENV.fetch('FRONTEND_URL', 'http://localhost:5173')}/auth/error?message=Could+not+authenticate+you+from+Google+account"
    end
  end

  def failure
    redirect_to "#{ENV.fetch('FRONTEND_URL', 'http://localhost:5173')}/auth/error?message=Authentication+failed"
  end
end
