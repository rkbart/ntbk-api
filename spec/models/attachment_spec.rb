require 'rails_helper'

RSpec.describe Attachment, type: :model do
  describe 'validations' do
    it 'validates filename presence' do
      attachment = build(:attachment, filename: nil)
      expect(attachment).not_to be_valid
      expect(attachment.errors[:filename]).to include("can't be blank")
    end

    it 'validates content_type presence' do
      attachment = build(:attachment, content_type: nil)
      expect(attachment).not_to be_valid
      expect(attachment.errors[:content_type]).to include("can't be blank")
    end

    it 'validates file_size presence' do
      attachment = build(:attachment, file_size: nil)
      expect(attachment).not_to be_valid
      expect(attachment.errors[:file_size]).to include("can't be blank")
    end
  end

  describe 'enums' do
    it 'defines preview_state enum' do
      expect(Attachment.preview_states.keys).to eq(%w[pending processing completed failed])
    end
  end

  describe 'scopes' do
    let!(:image_attachment) { create(:attachment, :image, document: create(:document)) }
    let!(:pdf_attachment) { create(:attachment, :pdf, document: create(:document)) }

    describe '.images' do
      it 'returns only image attachments' do
        expect(Attachment.images).to contain_exactly(image_attachment)
      end
    end

    describe '.by_type' do
      it 'filters by MIME type' do
        expect(Attachment.by_type('application/pdf')).to contain_exactly(pdf_attachment)
      end
    end
  end

  describe 'methods' do
    describe '#human_file_size' do
      it 'formats file size correctly' do
        attachment = build(:attachment, file_size: 1024)
        expect(attachment.human_file_size).to eq('1.0 KB')
      end
    end

    describe '#image?' do
      it 'returns true for image types' do
        attachment = build(:attachment, content_type: 'image/png')
        expect(attachment.image?).to be true
      end

      it 'returns false for non-image types' do
        attachment = build(:attachment, content_type: 'application/pdf')
        expect(attachment.image?).to be false
      end
    end

    describe '#pdf?' do
      it 'returns true for PDF type' do
        attachment = build(:attachment, content_type: 'application/pdf')
        expect(attachment.pdf?).to be true
      end

      it 'returns false for non-PDF types' do
        attachment = build(:attachment, content_type: 'image/png')
        expect(attachment.pdf?).to be false
      end
    end
  end
end
