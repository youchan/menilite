module Opal::UnitTest
  class AssertFailed < RuntimeError
    attr_reader :expected, :actual

    def initialize(expected, actual)
      @expected = expected
      @actual = actual
    end
  end

  module Assertions
    def assert(cond, message="")
      unless cond
        raise AssertFailed.new(true, cond, message)
      end
    end

    def assert_equals(expected, actual, message="")
      unless expected == actual
        raise AssertFailed.new(expected, actual, message)
      end
    end

    def assert_raises(exception, message="", &block)
      raises = false
      begin
        block.call
      rescue exception => e
        raises = true
      end

      unless raises
        raise AssertFailed.new("#{exception} will raise.", "no excetion raises.")
      end
    end
  end
end
