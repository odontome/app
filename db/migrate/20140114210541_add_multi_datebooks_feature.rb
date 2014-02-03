class AddMultiDatebooksFeature < ActiveRecord::Migration
  def self.up
    create_table :datebooks do |t|
      t.integer :practice_id
      t.string :name, :limit => 100

      t.timestamps
    end

    add_column :appointments, :datebook_id, :integer

    Practice.all.each do |practice|
      execute "insert into datebooks (practice_id, name, created_at, updated_at) values (#{ActiveRecord::Base.connection.quote(practice.id)}, #{ActiveRecord::Base.connection.quote(practice.name)}, '#{Time.now}', '#{Time.now}')"
    end

    Datebook.all.each do |datebook| 
    	Appointment.update_all "datebook_id = #{datebook.id}", "appointments.practice_id = #{datebook.practice_id}"
   	end

    remove_column :appointments, :practice_id
  end

  def self.down

  	add_column :appointments, :practice_id, :integer

    Datebook.all.each do |datebook|
    	Appointment.update_all "practice_id = #{datebook.practice_id}", "appointments.datebook_id = #{datebook.id}"
   	end

    remove_column :appointments, :datebook_id

    drop_table :datebooks
  end
end