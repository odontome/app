# frozen_string_literal: true

require 'rake'

module TestSupport
  module RakeTasks
    module_function

    def load!
      return if @loaded

      Rake::Task.define_task(:environment) unless Rake::Task.task_defined?(:environment)
      Dir[Rails.root.join('lib/tasks/**/*.rake')].sort.each { |task| load task }
      @loaded = true
    end
  end
end

class RakeTaskTestCase < ActiveSupport::TestCase
  class << self
    attr_reader :rake_task_name

    def rake_task(name)
      @rake_task_name = name

      setup { prepare_rake_task }
      teardown { reset_rake_task }
    end
  end

  private

  def prepare_rake_task
    task_name = self.class.rake_task_name
    return unless task_name

    TestSupport::RakeTasks.load!
    @task = Rake::Task[task_name]
    @task.reenable
  end

  def reset_rake_task
    @task&.reenable
  end
end
