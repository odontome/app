class AddEmailToPractice < ActiveRecord::Migration[5.1]
  def up
    add_column :practices, :email, :string
    Practice.update_all 'email = (select email from users
    		where practice_id = practices.id
    		order by id asc limit 1)'
  end

  def down
    remove_column :practices, :email
  end
end
