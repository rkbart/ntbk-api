class OauthIdentity < ApplicationRecord
  belongs_to :user

  validates :provider, presence: true
  validates :uid, presence: true
  validates :provider, uniqueness: { scope: :uid }
  validates :uid, uniqueness: { scope: :provider }

  # Provider constants
  GOOGLE = "google_oauth2"
  GITHUB = "github"

  scope :google, -> { where(provider: GOOGLE) }
  scope :github, -> { where(provider: GITHUB) }

  def google?
    provider == GOOGLE
  end

  def github?
    provider == GITHUB
  end
end
