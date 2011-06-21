class JqgridGenerator < Rails::Generators::NamedBase

  argument :columns, :type => :array, :default => [], :banner => "column column"

  source_root File.expand_path('../templates', __FILE__)


  def create_controller_files
    template 'controller.rb', File.join('app/controllers', class_path, "#{plural_name}_controller.rb")  
    template 'index.html.erb', File.join('app/views', file_path.pluralize, "index.html.erb")  
  end

  def model_name
    file_name
  end

  def camel
    file_name.camelcase
  end


end
