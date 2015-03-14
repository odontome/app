class UpdatePracticesLocale < ActiveRecord::Migration
  def up
  	Practice.where("locale = 'es_ES'").update_all("locale = 'es'")
    Practice.where("locale = 'en_US'").update_all("locale = 'en'")
  end

  def down
    Practice.where("locale = 'es'").update_all("locale = 'es_ES'")
    Practice.where("locale = 'en'").update_all("locale = 'en_US'")
  end
end
