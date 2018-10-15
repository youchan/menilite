require "opal/cli_options"
require "opal/cli"
require "tmpdir"

module Opal::UnitTest
  class Runner
    def initialize(directory)
      @directory = directory
    end

    def run
      tmpfile_path = "#{Dir.tmpdir}/tmp.rb"
      File.open(tmpfile_path, "w") do |tmpfile|
        Dir.glob("#{@directory}/**/*test.rb").each do |filename|
          tmpfile.write("require \"#{filename.sub(/^#{@directory}\//, "")}\"\n")
        end
        tmpfile.write(<<~SRC)
          require "opal/platform"
          result = Opal::UnitTest::TestCase.run
          Opal::UnitTest::ResultPrinter.print_summary(result)
          if result.failure_messages.count > 0 || result.errors.count > 0
            raise 'exit 1'
          end
        SRC
      end
      run_on_opal @directory, tmpfile_path

      File.delete tmpfile_path

      puts "Done."
    end

    def run_on_opal(dir, filename)
      options_hash = {
        file:     File.open(filename),
        filename: File.basename(filename),
        load_paths: ["./test", "./lib", dir]
      }

      cli = Opal::CLI.new options_hash

      begin
        cli.run
        exit cli.exit_status
      rescue Opal::CliRunners::RunnerError => e
        $stderr.puts e.message
        exit 72
      end
    end
  end
end
