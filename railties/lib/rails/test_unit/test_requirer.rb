require "active_support/core_ext/object/blank"
require "rake/file_list"

module Rails
  class TestRequirer # :nodoc:
    class << self
      def require_files(patterns)
        patterns = expand_patterns(patterns)

        Rake::FileList[patterns.compact.presence || "test/**/*_test.rb"].to_a.each do |file|
          require File.expand_path(file)
        end
      end

      private
        def expand_patterns(patterns)
          patterns.map do |arg|
            arg = arg.gsub(/(:\d+)+?$/, "")
            if Dir.exist?(arg)
              "#{arg}/**/*_test.rb"
            else
              arg
            end
          end
        end
    end
  end
end
