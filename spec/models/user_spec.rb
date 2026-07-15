require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      user = build(:user)
      expect(user).to be_valid
    end

    it 'requires email' do
      user = build(:user, email: nil)
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include("can't be blank")
    end

    it 'requires unique email' do
      create(:user, email: 'test@example.com')
      user = build(:user, email: 'test@example.com')
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include("has already been taken")
    end

    it 'downcases email before saving' do
      user = create(:user, email: 'TEST@EXAMPLE.COM')
      expect(user.email).to eq('test@example.com')
    end

    it 'requires password' do
      user = build(:user, password: nil)
      expect(user).not_to be_valid
      expect(user.errors[:password]).to include("can't be blank")
    end

    it 'requires password to be at least 6 characters' do
      user = build(:user, password: '12345')
      expect(user).not_to be_valid
      expect(user.errors[:password]).to include("is too short (minimum is 6 characters)")
    end
  end

  describe 'devise modules' do
    it 'includes database_authenticatable' do
      expect(User.devise_modules).to include(:database_authenticatable)
    end

    it 'includes registerable' do
      expect(User.devise_modules).to include(:registerable)
    end

    it 'includes recoverable' do
      expect(User.devise_modules).to include(:recoverable)
    end

    it 'includes validatable' do
      expect(User.devise_modules).to include(:validatable)
    end
  end

  describe 'serialization' do
    it 'serializes to JSON correctly' do
      user = create(:user)
      serializer = UserSerializer.new(user)
      json = ActiveModelSerializers::Adapter.create(serializer).as_json

      expect(json).to include(
        id: user.id,
        email: user.email
      )
      expect(json[:created_at]).to be_present
      expect(json[:updated_at]).to be_present
    end
  end
end
