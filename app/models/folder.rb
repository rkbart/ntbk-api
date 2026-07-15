class Folder < ApplicationRecord
  belongs_to :workspace
  belongs_to :parent, class_name: "Folder", optional: true
  has_many :subfolders, class_name: "Folder", foreign_key: :parent_id, dependent: :destroy
  has_many :documents, dependent: :destroy

  validates :name, presence: true, length: { maximum: 255 }
  validate :no_circular_references

  def ancestors
    folder = self
    ancestors = []
    while folder.parent_id.present?
      folder = folder.parent
      ancestors << folder
    end
    ancestors.reverse
  end

  def path
    (ancestors + [ self ]).map(&:name).join(" / ")
  end

  private

  def no_circular_references
    return unless parent_id.present?

    if parent_id == id
      errors.add(:parent_id, "can't be self")
      return
    end

    current = parent
    while current.present?
      if current.id == id
        errors.add(:parent_id, "would create circular reference")
        return
      end
      current = current.parent
    end
  end
end
