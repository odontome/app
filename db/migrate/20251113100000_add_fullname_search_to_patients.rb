# frozen_string_literal: true

class AddFullnameSearchToPatients < ActiveRecord::Migration[7.0]
  def up
    add_column :patients, :fullname_search, :string

    execute <<~SQL.squish
      UPDATE patients
         SET fullname_search = LOWER(COALESCE(firstname, '')) || ' ' || LOWER(COALESCE(lastname, ''))
    SQL

    add_index :patients, :fullname_search, using: :gin, opclass: :gin_trgm_ops,
                                           name: 'index_patients_on_fullname_search'

    remove_index :patients, name: 'index_patients_on_fullname_trgm'
  end

  def down
    remove_index :patients, name: 'index_patients_on_fullname_search'
    remove_column :patients, :fullname_search

    add_index_sql = <<~SQL.squish
      CREATE INDEX index_patients_on_fullname_trgm
        ON patients USING gin (lower((firstname || ' ' || lastname)) gin_trgm_ops)
    SQL

    execute add_index_sql
  end
end
