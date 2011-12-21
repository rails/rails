module Rails
  # Don't abort when tests fail; move on the next test task.
  # Silence the default description to cut down on `rake -T` noise.
  class SubTestTask < Rake::TestTask
    # Create the tasks defined by this task lib.
    def define
      lib_path = @libs.join(File::PATH_SEPARATOR)
      task @name do
        run_code = ''
        RakeFileUtils.verbose(@verbose) do
          run_code =
            case @loader
            when :direct
              "-e 'ARGV.each{|f| load f}'"
            when :testrb
              "-S testrb #{fix}"
            when :rake
              rake_loader
            end
          @ruby_opts.unshift( "-I\"#{lib_path}\"" )
          @ruby_opts.unshift( "-w" ) if @warning

          begin
            ruby @ruby_opts.join(" ") +
              " \"#{run_code}\" " +
              file_list.collect { |fn| "\"#{fn}\"" }.join(' ') +
              " #{option_list}"
          rescue => error
            warn "Error running #{name}: #{error.inspect}"
          end
        end
      end
      self
    end
  end
end
