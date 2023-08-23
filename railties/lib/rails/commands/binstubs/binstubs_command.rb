# frozen_string_literal: true

require "pathname"

module Rails
  module Command
    class BinstubsCommand < Base # :nodoc:
      self.bin = "rails"

      desc "change [PATHS...]",
        "Change binstubs to have a specific shebang, Unix-style line endings, and execute permission"
      option :pattern, type: :string, default: "ruby",
        desc: "Change binstubs with a shebang matching this pattern (regex)."
      option :interpreter, type: :string, default: "/usr/bin/env #{File.basename Thor::Util.ruby_command}",
        desc: "The new shebang interpreter."
      def change(*paths)
        @shebang_pattern = /#{options[:pattern]}/
        @shebang = "#!#{options[:interpreter]}"
        paths = ["bin"] if paths.empty?

        each_file(*paths) { |path| change_binstub(path) }
      end

      private
        def each_file(*paths, &block)
          paths.each do |path|
            path = Pathname(path)

            if path.file?
              block.call(path)
            else
              each_file(*path.children, &block)
            end
          end
        end

        def change_binstub(path)
          path.open("r+") do |file|
            shebang = file.read(2)

            if shebang == "#!"
              shebang << file.gets.chomp!
              shebang = @shebang if @shebang_pattern.match?(shebang)

              content = file.read
              content.delete!("\r")

              file.rewind
              file.truncate(file.write(shebang, "\n", content))
              path.chmod(0755 & ~File.umask)
            end
          end
        end
    end
  end
end
