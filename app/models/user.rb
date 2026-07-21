class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: [ :google_oauth2 ]

  # Associations
  has_many :workspaces, dependent: :destroy
  has_many :tags, dependent: :destroy
  has_many :conversations, dependent: :destroy
  has_many :oauth_identities, dependent: :destroy

  # Validations
  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :name, length: { maximum: 50 }, allow_blank: true
  validates :password, length: { minimum: 6 }, if: :password_required?

  # Callbacks
  before_save :downcase_email
  after_create :create_default_workspace

  # OmniAuth methods
  def self.from_omniauth(auth)
    identity = OauthIdentity.find_or_initialize_by(
      provider: auth.provider,
      uid: auth.uid
    )

    if identity.user.present?
      # Identity exists, return the user
      identity.user
    else
      # Check if user exists by email
      user = User.find_by(email: auth.info.email)

      if user
        # User exists, link the identity
        identity.user = user
        identity.save!
        user
      else
        # Create new user and identity
        user = User.create!(
          email: auth.info.email,
          name: auth.info.name,
          password: Devise.friendly_token[0, 20]
        )
        identity.user = user
        identity.save!
        user
      end
    end
  end

  def self.new_with_session(params, session)
    super.tap do |user|
      if data = session["devise.google_oauth2_data"] && session["devise.google_oauth2_data"]["extra"]["raw_info"]
        user.email = data["email"] if user.email.blank?
      end
    end
  end

  # Check if user has a linked OAuth provider
  def oauth_connected?(provider)
    oauth_identities.exists?(provider: provider.to_s)
  end

  # Get OAuth identity for a provider
  def oauth_identity(provider)
    oauth_identities.find_by(provider: provider.to_s)
  end

  # Check if user has a password set (OAuth users may not have one)
  def has_password?
    # Checks if user explicitly set a password (not auto-generated for OAuth)
    password_set_by_user?
  end

  private

  def downcase_email
    self.email = email.downcase if email.present?
  end

  def password_required?
    # Skip password validation for OAuth users
    new_record? || (password.present? && !oauth_connected?(:google_oauth2))
  end

  def create_default_workspace
    workspaces.create(name: "My Workspace")
  end
end
