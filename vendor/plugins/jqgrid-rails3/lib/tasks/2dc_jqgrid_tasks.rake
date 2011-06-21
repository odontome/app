namespace :jqgrid do

	desc "Copy javascripts, stylesheets and images to public"
	task :install do
	  Rake::Task[ "jqgrid:uninstall" ].execute
    %w(javascripts stylesheets).each do |dir|
      source = File.expand_path(File.join(File.dirname(__FILE__),'..', '..', 'public', dir))
      target = File.join(Rails.root, 'public', dir, 'jqgrid')
      FileUtils.mkdir_p target
      FileUtils.copy_entry(source, target, :verbose => true) 
    end
	end

  desc 'Remove javascripts, stylesheets and images from public'
  task :uninstall do
    %w(javascripts stylesheets).each do |dir|
      target = File.join(Rails.root, 'public', dir, 'jqgrid')
      FileUtils.rm_rf(target, :verbose => true)
    end
  end
  
end
