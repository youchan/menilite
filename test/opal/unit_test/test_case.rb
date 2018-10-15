require "ostruct"

module Opal::UnitTest
  class TestCase
    include Assertions

    def self.inherited(subclass)
      (@test_cases ||= []) << subclass
      subclass.define_singleton_method(:test) do |desc, &block|
        TestCase.register_test subclass, OpenStruct.new({ desc: desc, block: block })
      end
    end

    def self.register_test(subclass, test)
      ((@tests ||= {})[subclass] ||= []) << test
    end

    def self.run
      success_count = 0
      failure_messages = []
      errors = []
      @test_cases&.each do |test_case|
        instance = test_case.new
        @tests[test_case]&.each do |test|
          print("\e[32m")
          begin
            instance.instance_eval(&test.block)
            print "."
            success_count += 1
          rescue AssertFailed => e
            print "\e[31mF\e[32m"
            failure_messages << OpenStruct.new({ desc: test.desc, error: e })
          rescue => e
            print "\e[31mE\e[32m"
            errors << OpenStruct.new({ desc: test.desc, error: e })
          end
          print( "\e[37m")
        end
      end
      puts
      OpenStruct.new(success_count: success_count, failure_messages: failure_messages, errors: errors)
    end
  end
end
