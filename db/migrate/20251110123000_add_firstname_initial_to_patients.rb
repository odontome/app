# frozen_string_literal: true

class AddFirstnameInitialToPatients < ActiveRecord::Migration[7.0]
  def up
    add_column :patients, :firstname_initial, :string, limit: 1

    execute(<<~SQL.squish)
      UPDATE patients
         SET firstname_initial = LOWER(SUBSTRING(firstname, 1, 1))
    SQL

    add_index :patients, %i[practice_id firstname_initial]
  end

  def down
    remove_index :patients, %i[practice_id firstname_initial]
    remove_column :patients, :firstname_initial
  end
end
