require_relative "opal/unit_test/runner"

runner = Opal::UnitTest::Runner.new(File.expand_path("../test", __FILE__))
runner.run
