class Workspace < ApplicationRecord
  belongs_to :user
  has_many :folders, dependent: :destroy
  has_many :documents, dependent: :destroy

  validates :name, presence: true, length: { maximum: 255 }
end
