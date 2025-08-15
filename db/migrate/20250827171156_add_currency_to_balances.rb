class AddCurrencyToBalances < ActiveRecord::Migration[7.2]
  def change
    add_column :balances, :currency, :string
  end
end
