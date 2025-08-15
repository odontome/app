# frozen_string_literal: true

class RenameCurrencyUnitToCurrencyInPractices < ActiveRecord::Migration[7.2]
  def up
    add_column :practices, :currency, :string, default: 'mxn', null: false

    # Update all rows in SQL (much faster than Ruby iteration)
    execute <<~SQL
      UPDATE practices
      SET currency = CASE
        WHEN currency_unit = '$' THEN 'mxn'
        ELSE 'usd'
      END
    SQL

    remove_column :practices, :currency_unit
  end

  def down
    add_column :practices, :currency_unit, :string, default: '$', null: false

    # Reverse mapping: MXN → $, everything else → $
    execute <<~SQL
      UPDATE practices
      SET currency_unit = CASE
        WHEN currency = 'mxn' THEN '$'
        ELSE '$'
      END
    SQL

    remove_column :practices, :currency
  end
end
