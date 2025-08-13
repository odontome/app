# frozen_string_literal: true

class CreateVersions < ActiveRecord::Migration[7.2]
  # The largest text column available in all supported RDBMS is
  # 1024^3 - 1 bytes, roughly one gibibyte.  We specify a size
  # so that MySQL will use `longtext` instead of `text`.  Otherwise,
  # when serializing very large objects, `text` might not be big enough.
  def change
    create_table :versions do |t|
      t.string   :item_type, limit: 191, null: false
      t.bigint   :item_id,   null: false
      t.string   :event,     null: false
      t.string   :whodunnit
      t.text     :object, limit: 1073741823
      t.text     :object_changes, limit: 1073741823
      t.bigint   :practice_id
      t.string   :user_agent
      t.string   :remote_ip
      t.datetime :created_at

      t.index [:item_type, :item_id]
      t.index [:practice_id]
      t.index [:created_at]
      t.index [:whodunnit]
    end
  end
end