class CreatePractices < ActiveRecord::Migration[5.0]
  def self.up
    create_table :practices do |t|
      t.string :name
      t.string :locale, default: 'en_US'
      t.string :timezone, default: 'UTC'
      t.string :status, default: 'unconfirmed'

      t.timestamps
    end
  end

  def self.down
    drop_table :practices
  end
end
