class UpdatePracticesLocale < ActiveRecord::Migration
  def up
  	Practice.update_all "locale = 'es'", "locale = 'es_ES'"
  	Practice.update_all "locale = 'en'", "locale = 'en_US'"
  end

  def down
  	Practice.update_all "locale = 'es_ES'", "locale = 'es'"
  	Practice.update_all "locale = 'en_US'", "locale = 'en'"
  end
end
