# Database cleaner configuration (optional - using transactional fixtures by default)
# If you need to switch strategies, uncomment and configure:

# RSpec.configure do |config|
#   config.before(:suite) do
#     DatabaseCleaner.strategy = :transaction
#     DatabaseCleaner.clean_with(:truncation)
#   end
#
#   config.around(:each) do |example|
#     DatabaseCleaner.cleaning do
#       example.run
#     end
#   end
# end
