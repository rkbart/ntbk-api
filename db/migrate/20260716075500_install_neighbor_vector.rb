class InstallNeighborVector < ActiveRecord::Migration[8.1]
  def up
    # Check if pgvector extension is available before enabling
    begin
      enable_extension "vector"
    rescue ActiveRecord::StatementInvalid => e
      if e.message.include?("extension \"vector\" is not available")
        puts "WARNING: pgvector extension not available. Vector search features will be disabled."
        puts "Install pgvector: https://github.com/pgvector/pgvector#installation"
      else
        raise e
      end
    end
  end

  def down
    begin
      disable_extension "vector"
    rescue ActiveRecord::StatementInvalid
      # Extension might not exist in test environment
    end
  end
end
