class DocumentTag < ApplicationRecord
  belongs_to :document
  belongs_to :tag

  validates :document_id, uniqueness: { scope: :tag_id }
end
