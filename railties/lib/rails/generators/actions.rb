# frozen_string_literal: true

require "shellwords"
require "active_support/core_ext/kernel/reporting"
require "active_support/core_ext/string/strip"

module Rails
  module Generators
    module Actions
      def initialize(*) # :nodoc:
        super
        @indentation = 0
      end

      # Adds a +gem+ declaration to the +Gemfile+ for the specified gem.
      #
      #   gem "rspec", group: :test
      #   gem "technoweenie-restful-authentication", lib: "restful-authentication", source: "http://gems.github.com/"
      #   gem "rails", "3.0", git: "https://github.com/rails/rails"
      #   gem "RedCloth", ">= 4.1.0", "< 4.2.0"
      #   gem "rspec", comment: "Put this comment above the gem declaration"
      #
      # Note that this method only adds the gem to the +Gemfile+; it does not
      # install the gem.
      #
      # ==== Options
      #
      # [+:version+]
      #   The version constraints for the gem, specified as a string or an
      #   array of strings:
      #
      #     gem "my_gem", version: "~> 1.1"
      #     gem "my_gem", version: [">= 1.1", "< 2.0"]
      #
      #   Alternatively, can be specified as one or more arguments following the
      #   gem name:
      #
      #     gem "my_gem", ">= 1.1", "< 2.0"
      #
      # [+:comment+]
      #   Outputs a comment above the +gem+ declaration in the +Gemfile+.
      #
      #     gem "my_gem", comment: "First line.\nSecond line."
      #
      #   Outputs:
      #
      #     # First line.
      #     # Second line.
      #     gem "my_gem"
      #
      # [+:group+]
      #   The gem group in the +Gemfile+ that the gem belongs to.
      #
      # [+:git+]
      #   The URL of the git repository for the gem.
      #
      # Any additional options passed to this method will be appended to the
      # +gem+ declaration in the +Gemfile+. For example:
      #
      #   gem "my_gem", comment: "Edge my_gem", git: "https://example.com/my_gem.git", branch: "master"
      #
      # Outputs:
      #
      #   # Edge my_gem
      #   gem "my_gem", git: "https://example.com/my_gem.git", branch: "master"
      #
      def gem(*args)
        options = args.extract_options!
        name, *versions = args

        # Set the message to be shown in logs. Uses the git repo if one is given,
        # otherwise use name (version).
        parts, message = [ quote(name) ], name.dup

        # Output a comment above the gem declaration.
        comment = options.delete(:comment)

        if versions = versions.any? ? versions : options.delete(:version)
          _versions = Array(versions)
          _versions.each do |version|
            parts << quote(version)
          end
          message << " (#{_versions.join(", ")})"
        end
        message = options[:git] if options[:git]

        log :gemfile, message

        parts << quote(options) unless options.empty?

        in_root do
          str = []
          if comment
            comment.each_line do |comment_line|
              str << indentation
              str << "# #{comment_line}"
            end
            str << "\n"
          end
          str << indentation
          str << "gem #{parts.join(", ")}"
          append_file_with_newline "Gemfile", str.join, verbose: false
        end
      end

      # Wraps gem entries inside a group.
      #
      #   gem_group :development, :test do
      #     gem "rspec-rails"
      #   end
      def gem_group(*names, &block)
        options = names.extract_options!
        str = names.map(&:inspect)
        str << quote(options) unless options.empty?
        str = str.join(", ")
        log :gemfile, "group #{str}"

        in_root do
          append_file_with_newline "Gemfile", "\ngroup #{str} do", force: true
          with_indentation(&block)
          append_file_with_newline "Gemfile", "end", force: true
        end
      end

      def github(repo, options = {}, &block)
        str = [quote(repo)]
        str << quote(options) unless options.empty?
        str = str.join(", ")
        log :github, "github #{str}"

        in_root do
          if @indentation.zero?
            append_file_with_newline "Gemfile", "\ngithub #{str} do", force: true
          else
            append_file_with_newline "Gemfile", "#{indentation}github #{str} do", force: true
          end
          with_indentation(&block)
          append_file_with_newline "Gemfile", "#{indentation}end", force: true
        end
      end

      # Add the given source to +Gemfile+
      #
      # If block is given, gem entries in block are wrapped into the source group.
      #
      #   add_source "http://gems.github.com/"
      #
      #   add_source "http://gems.github.com/" do
      #     gem "rspec-rails"
      #   end
      def add_source(source, options = {}, &block)
        log :source, source

        in_root do
          if block
            append_file_with_newline "Gemfile", "\nsource #{quote(source)} do", force: true
            with_indentation(&block)
            append_file_with_newline "Gemfile", "end", force: true
          else
            prepend_file "Gemfile", "source #{quote(source)}\n", verbose: false
          end
        end
      end

      # Adds configuration code to a \Rails runtime environment.
      #
      # By default, adds code inside the +Application+ class in
      # +config/application.rb+ so that it applies to all environments.
      #
      #   environment %(config.asset_host = "cdn.provider.com")
      #
      # Results in:
      #
      #   # config/application.rb
      #   class Application < Rails::Application
      #     config.asset_host = "cdn.provider.com"
      #     # ...
      #   end
      #
      # If the +:env+ option is specified, the code will be added to the
      # corresponding file in +config/environments+ instead.
      #
      #   environment %(config.asset_host = "localhost:3000"), env: "development"
      #
      # Results in:
      #
      #   # config/environments/development.rb
      #   Rails.application.configure do
      #     config.asset_host = "localhost:3000"
      #     # ...
      #   end
      #
      # +:env+ can also be an array. In which case, the code is added to each
      # corresponding file in +config/environments+.
      #
      # The code can also be specified as the return value of the block:
      #
      #   environment do
      #     %(config.asset_host = "cdn.provider.com")
      #   end
      #
      #   environment(nil, env: "development") do
      #     %(config.asset_host = "localhost:3000")
      #   end
      #
      def environment(data = nil, options = {})
        sentinel = "class Application < Rails::Application\n"
        env_file_sentinel = "Rails.application.configure do\n"
        data ||= yield if block_given?

        in_root do
          if options[:env].nil?
            inject_into_file "config/application.rb", optimize_indentation(data, 4), after: sentinel, verbose: false
          else
            Array(options[:env]).each do |env|
              inject_into_file "config/environments/#{env}.rb", optimize_indentation(data, 2), after: env_file_sentinel, verbose: false
            end
          end
        end
      end
      alias :application :environment

      # Runs one or more git commands.
      #
      #   git :init
      #   # => runs `git init`
      #
      #   git add: "this.file that.rb"
      #   # => runs `git add this.file that.rb`
      #
      #   git commit: "-m 'First commit'"
      #   # => runs `git commit -m 'First commit'`
      #
      #   git add: "good.rb", rm: "bad.cxx"
      #   # => runs `git add good.rb; git rm bad.cxx`
      #
      def git(commands = {})
        if commands.is_a?(Symbol)
          run "git #{commands}"
        else
          commands.each do |cmd, options|
            run "git #{cmd} #{options}"
          end
        end
      end

      # Creates a file in +vendor/+. The contents can be specified as an
      # argument or as the return value of the block.
      #
      #   vendor "foreign.rb", <<~RUBY
      #     # Foreign code is fun
      #   RUBY
      #
      #   vendor "foreign.rb" do
      #     "# Foreign code is fun"
      #   end
      #
      def vendor(filename, data = nil)
        log :vendor, filename
        data ||= yield if block_given?
        create_file("vendor/#{filename}", optimize_indentation(data), verbose: false)
      end

      # Creates a file in +lib/+. The contents can be specified as an argument
      # or as the return value of the block.
      #
      #   lib "foreign.rb", <<~RUBY
      #     # Foreign code is fun
      #   RUBY
      #
      #   lib "foreign.rb" do
      #     "# Foreign code is fun"
      #   end
      #
      def lib(filename, data = nil)
        log :lib, filename
        data ||= yield if block_given?
        create_file("lib/#{filename}", optimize_indentation(data), verbose: false)
      end

      # Creates a Rake tasks file in +lib/tasks/+. The code can be specified as
      # an argument or as the return value of the block.
      #
      #   rakefile "bootstrap.rake", <<~RUBY
      #     task :bootstrap do
      #       puts "Boots! Boots! Boots!"
      #     end
      #   RUBY
      #
      #   rakefile "bootstrap.rake" do
      #     project = ask("What is the UNIX name of your project?")
      #
      #     <<~RUBY
      #       namespace :#{project} do
      #         task :bootstrap do
      #           puts "Boots! Boots! Boots!"
      #         end
      #       end
      #     RUBY
      #   end
      #
      def rakefile(filename, data = nil)
        log :rakefile, filename
        data ||= yield if block_given?
        create_file("lib/tasks/#{filename}", optimize_indentation(data), verbose: false)
      end

      # Creates an initializer file in +config/initializers/+. The code can be
      # specified as an argument or as the return value of the block.
      #
      #   initializer "api.rb", <<~RUBY
      #     API_KEY = "123456"
      #   RUBY
      #
      #   initializer "api.rb" do
      #     %(API_KEY = "123456")
      #   end
      #
      def initializer(filename, data = nil)
        log :initializer, filename
        data ||= yield if block_given?
        create_file("config/initializers/#{filename}", optimize_indentation(data), verbose: false)
      end

      # Runs another generator.
      #
      #   generate "scaffold", "Post title:string body:text"
      #   generate "scaffold", "Post", "title:string", "body:text"
      #
      # The first argument is the generator name, and the remaining arguments
      # are joined together and passed to the generator.
      def generate(what, *args)
        log :generate, what

        options = args.extract_options!
        options[:abort_on_failure] = !options[:inline]

        rails_command "generate #{what} #{args.join(" ")}", options
      end

      # Runs the specified Rake task.
      #
      #   rake "db:migrate"
      #   rake "db:migrate", env: "production"
      #   rake "db:migrate", abort_on_failure: true
      #   rake "stats", capture: true
      #   rake "gems:install", sudo: true
      #
      # ==== Options
      #
      # [+:env+]
      #   The \Rails environment in which to run the task. Defaults to
      #   <tt>ENV["RAILS_ENV"] || "development"</tt>.
      #
      # [+:abort_on_failure+]
      #   Whether to halt the generator if the task exits with a non-success
      #   exit status.
      #
      # [+:capture+]
      #   Whether to capture and return the output of the task.
      #
      # [+:sudo+]
      #   Whether to run the task using +sudo+.
      def rake(command, options = {})
        execute_command :rake, command, options
      end

      # Runs the specified \Rails command.
      #
      #   rails_command "db:migrate"
      #   rails_command "db:migrate", env: "production"
      #   rails_command "db:migrate", abort_on_failure: true
      #   rails_command "stats", capture: true
      #   rails_command "gems:install", sudo: true
      #
      # ==== Options
      #
      # [+:env+]
      #   The \Rails environment in which to run the command. Defaults to
      #   <tt>ENV["RAILS_ENV"] || "development"</tt>.
      #
      # [+:abort_on_failure+]
      #   Whether to halt the generator if the command exits with a non-success
      #   exit status.
      #
      # [+:capture+]
      #   Whether to capture and return the output of the command.
      #
      # [+:sudo+]
      #   Whether to run the command using +sudo+.
      def rails_command(command, options = {})
        if options[:inline]
          log :rails, command
          command, *args = Shellwords.split(command)
          in_root do
            silence_warnings do
              ::Rails::Command.invoke(command, args, **options)
            end
          end
        else
          execute_command :rails, command, options
        end
      end

      # Make an entry in \Rails routing file <tt>config/routes.rb</tt>
      #
      #   route "root 'welcome#index'"
      #   route "root 'admin#index'", namespace: :admin
      def route(routing_code, namespace: nil)
        namespace = Array(namespace)
        namespace_pattern = route_namespace_pattern(namespace)
        routing_code = namespace.reverse.reduce(routing_code) do |code, name|
          "namespace :#{name} do\n#{rebase_indentation(code, 2)}end"
        end

        log :route, routing_code

        in_root do
          if namespace_match = match_file("config/routes.rb", namespace_pattern)
            base_indent, *, existing_block_indent = namespace_match.captures.compact.map(&:length)
            existing_line_pattern = /^[ ]{,#{existing_block_indent}}\S.+\n?/
            routing_code = rebase_indentation(routing_code, base_indent + 2).gsub(existing_line_pattern, "")
            namespace_pattern = /#{Regexp.escape namespace_match.to_s}/
          end

          inject_into_file "config/routes.rb", routing_code, after: namespace_pattern, verbose: false, force: false

          if behavior == :revoke && namespace.any? && namespace_match
            empty_block_pattern = /(#{namespace_pattern})((?:\s*end\n){1,#{namespace.size}})/
            gsub_file "config/routes.rb", empty_block_pattern, verbose: false, force: true do |matched|
              beginning, ending = empty_block_pattern.match(matched).captures
              ending.sub!(/\A\s*end\n/, "") while !ending.empty? && beginning.sub!(/^[ ]*namespace .+ do\n\s*\z/, "")
              beginning + ending
            end
          end
        end
      end

      # Reads the given file at the source root and prints it in the console.
      #
      #   readme "README"
      def readme(path)
        log File.read(find_in_source_paths(path))
      end

      private
        # Define log for backwards compatibility. If just one argument is sent,
        # invoke +say+, otherwise invoke +say_status+.
        def log(*args) # :doc:
          if args.size == 1
            say args.first.to_s
          else
            args << (behavior == :invoke ? :green : :red)
            say_status(*args)
          end
        end

        # Runs the supplied command using either +rake+ or +rails+
        # based on the executor parameter provided.
        def execute_command(executor, command, options = {}) # :doc:
          log executor, command
          sudo = options[:sudo] && !Gem.win_platform? ? "sudo " : ""
          config = {
            env: { "RAILS_ENV" => (options[:env] || ENV["RAILS_ENV"] || "development") },
            verbose: false,
            capture: options[:capture],
            abort_on_failure: options[:abort_on_failure],
          }

          in_root { run("#{sudo}#{Shellwords.escape Gem.ruby} bin/#{executor} #{command}", config) }
        end

        # Always returns value in double quotes.
        def quote(value) # :doc:
          if value.respond_to? :each_pair
            return value.map do |k, v|
              "#{k}: #{quote(v)}"
            end.join(", ")
          end
          return value.inspect unless value.is_a? String

          "\"#{value.tr("'", '"')}\""
        end

        # Returns optimized string with indentation
        def optimize_indentation(value, amount = 0) # :doc:
          return "#{value}\n" unless value.is_a?(String)
          "#{value.strip_heredoc.indent(amount).chomp}\n"
        end
        alias rebase_indentation optimize_indentation

        # Returns a string corresponding to the current indentation level
        # (i.e. 2 * <code>@indentation</code> spaces). See also
        # #with_indentation, which can be used to manage the indentation level.
        def indentation # :doc:
          "  " * @indentation
        end

        # Increases the current indentation indentation level for the duration
        # of the given block, and decreases it after the block ends. Call
        # #indentation to get an indentation string.
        def with_indentation(&block) # :doc:
          @indentation += 1
          instance_eval(&block)
        ensure
          @indentation -= 1
        end

        # Append string to a file with a newline if necessary
        def append_file_with_newline(path, str, options = {})
          gsub_file path, /\n?\z/, options do |match|
            match.end_with?("\n") ? "" : "\n#{str}\n"
          end
        end

        def match_file(path, pattern)
          File.read(path).match(pattern) if File.exist?(path)
        end

        def route_namespace_pattern(namespace)
          namespace.each_with_index.reverse_each.reduce(nil) do |pattern, (name, i)|
            cumulative_margin = "\\#{i + 1}[ ]{2}"
            blank_or_indented_line = "^[ ]*\n|^#{cumulative_margin}.*\n"
            "(?:(?:#{blank_or_indented_line})*?^(#{cumulative_margin})namespace :#{name} do\n#{pattern})?"
          end.then do |pattern|
            /^([ ]*).+\.routes\.draw do[ ]*\n#{pattern}/
          end
        end
    end
  end
end
