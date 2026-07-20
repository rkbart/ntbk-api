class Conversation < ApplicationRecord
  belongs_to :user
  belongs_to :workspace, optional: true
  has_many :messages, dependent: :destroy

  validates :title, length: { maximum: 255 }

  scope :recent, -> { order(last_message_at: :desc) }

  def last_message
    messages.order(created_at: :desc).first
  end

  def message_count
    messages.count
  end
end
