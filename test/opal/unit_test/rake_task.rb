require 'rake'
require_relative 'runner'

module Opal::UnitTest
  class RakeTask
    include Rake::DSL
    DEFAULT_NAME = 'test:opal'
    attr_reader :rake_task

    def initialize(name = DEFAULT_NAME, directory)
      runner = Opal::UnitTest::Runner.new(directory)
      desc 'Run Opal unit test'
      @rake_task = task name do
        runner.run
      end
    end
  end
end
