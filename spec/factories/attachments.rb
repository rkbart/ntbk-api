FactoryBot.define do
  factory :attachment do
    document
    filename { "test_file.txt" }
    content_type { "text/plain" }
    file_size { 1024 }
    metadata { {} }
    preview_state { 'pending' }

    after(:build) do |attachment|
      if attachment.filename.present? && attachment.content_type.present? && !attachment.file.attached?
        attachment.file.attach(
          io: StringIO.new("test content"),
          filename: attachment.filename,
          content_type: attachment.content_type
        )
      end
    end

    trait :image do
      content_type { "image/jpeg" }
      filename { "photo.jpg" }
    end

    trait :pdf do
      content_type { "application/pdf" }
      filename { "document.pdf" }
    end

    trait :text do
      content_type { "text/plain" }
      filename { "notes.txt" }
    end
  end
end
