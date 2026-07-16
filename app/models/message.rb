class Message < ApplicationRecord
  belongs_to :conversation

  validates :role, inclusion: { in: %w[user assistant system] }
  validates :content, presence: true

  scope :chronological, -> { order(created_at: :asc) }

  def user?
    role == "user"
  end

  def assistant?
    role == "assistant"
  end
end
