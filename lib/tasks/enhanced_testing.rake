# frozen_string_literal: true

namespace :test do
  desc 'Run unit tests (models and units)'
  task units: :environment do
    $LOAD_PATH << 'test'
    
    test_files = Dir['test/unit/**/*_test.rb'] + Dir['test/models/**/*_test.rb']
    
    if test_files.empty?
      puts "No unit test files found"
    else
      test_files.each { |file| require file }
    end
  end

  desc 'Run functional tests (controllers)'
  task functionals: :environment do
    $LOAD_PATH << 'test'
    
    test_files = Dir['test/functional/**/*_test.rb']
    
    if test_files.empty?
      puts "No functional test files found"
    else
      test_files.each { |file| require file }
    end
  end

  desc 'Run integration tests'
  task integration: :environment do
    $LOAD_PATH << 'test'
    
    test_files = Dir['test/integration/**/*_test.rb']
    
    if test_files.empty?
      puts "No integration test files found"
    else
      test_files.each { |file| require file }
    end
  end

  desc 'Run all tests with coverage reporting'
  task coverage: :environment do
    ENV['COVERAGE'] = 'true'
    Rake::Task['test'].invoke
  end

  desc 'Run security audit checks'
  task security: :environment do
    puts "Running Bundler security audit..."
    system('bundle exec bundler-audit check --update') or exit(1)
    
    puts "Checking for vulnerable gems..."
    system('gem install ruby_audit && ruby-audit check') or puts "Warning: ruby_audit not available"
  end

  desc 'Run code quality checks'
  task quality: :environment do
    puts "Running RuboCop..."
    system('bundle exec rubocop --parallel --format progress') or exit(1)
  end

  desc 'Run comprehensive test suite (quality + security + coverage)'
  task comprehensive: [:quality, :security, :coverage]
end

desc 'Run tests with timing information'
task 'test:profile' => :environment do
  ENV['TESTOPTS'] = '--profile=10'
  Rake::Task['test'].invoke
end