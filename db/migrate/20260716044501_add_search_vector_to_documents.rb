class AddSearchVectorToDocuments < ActiveRecord::Migration[8.1]
  def up
    # Add tsvector column for full-text search
    add_column :documents, :search_vector, :tsvector

    # GIN index on search_vector for fast full-text queries
    add_index :documents, :search_vector, using: :gin

    # Trigger to auto-update search_vector on INSERT/UPDATE
    execute <<~SQL
      CREATE OR REPLACE FUNCTION documents_search_vector_update() RETURNS trigger AS $$
      BEGIN
        NEW.search_vector :=
          setweight(to_tsvector('english', COALESCE(NEW.title, '')), 'A') ||
          setweight(to_tsvector('english', COALESCE(NEW.body, '')), 'B');
        RETURN NEW;
      END
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER documents_search_vector_trigger
        BEFORE INSERT OR UPDATE OF title, body
        ON documents
        FOR EACH ROW
        EXECUTE FUNCTION documents_search_vector_update();
    SQL

    # Backfill existing documents
    execute <<~SQL
      UPDATE documents SET search_vector =
        setweight(to_tsvector('english', COALESCE(title, '')), 'A') ||
        setweight(to_tsvector('english', COALESCE(body, '')), 'B');
    SQL
  end

  def down
    execute "DROP TRIGGER IF EXISTS documents_search_vector_trigger ON documents"
    execute "DROP FUNCTION IF EXISTS documents_search_vector_update()"
    remove_index :documents, :search_vector
    remove_column :documents, :search_vector
  end
end
