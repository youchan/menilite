module Opal::UnitTest
  class ResultPrinter
    def self.print_summary(result)
      result.failure_messages.each do |failure_message|
        puts "\e[33m" + failure_message.desc + "\e[37m"
        puts "\e[31massertion failed: " + failure_message.error.message + "\e[37m"
        puts "expected: \e[32m" + failure_message.error.expected.to_s + "\e[37m"
        puts "actual: \e[31m" + failure_message.error.actual.to_s + "\e[37m"
        puts
      end

      result.errors.each do |error|
        puts "\e[33m" + error.desc + "\e[37m"
        print "\e[31m"
        puts error.error.message
        puts error.error.backtrace
        puts "\e[37m"
      end

      print "\e[32m" if result.success_count > 0
      print "#{result.success_count} success, "
      if result.failure_messages.count > 0
        print "\e[31m"
      else
        print "\e[37m"
      end
      print "#{result.failure_messages.count} failures, "
      if result.errors.count > 0
        print "\e[31m"
      else
        print "\e[37m"
      end
      print "#{result.errors.count} errors."
      puts
    end
  end
end
