module Rails
  module Generators
    module Actions
      def initialize(*) # :nodoc:
        super
        @in_group = nil
        @after_bundle_callbacks = []
      end

      # Adds an entry into +Gemfile+ for the supplied gem.
      #
      #   gem "rspec", group: :test
      #   gem "technoweenie-restful-authentication", lib: "restful-authentication", source: "http://gems.github.com/"
      #   gem "rails", "3.0", git: "git://github.com/rails/rails"
      def gem(*args)
        options = args.extract_options!
        name, version = args

        # Set the message to be shown in logs. Uses the git repo if one is given,
        # otherwise use name (version).
        parts, message = [ quote(name) ], name.dup
        if version ||= options.delete(:version)
          parts   << quote(version)
          message << " (#{version})"
        end
        message = options[:git] if options[:git]

        log :gemfile, message

        options.each do |option, value|
          parts << "#{option}: #{quote(value)}"
        end

        in_root do
          str = "gem #{parts.join(", ")}"
          str = "  " + str if @in_group
          str = "\n" + str
          append_file "Gemfile", str, verbose: false
        end
      end

      # Wraps gem entries inside a group.
      #
      #   gem_group :development, :test do
      #     gem "rspec-rails"
      #   end
      def gem_group(*names, &block)
        name = names.map(&:inspect).join(", ")
        log :gemfile, "group #{name}"

        in_root do
          append_file "Gemfile", "\ngroup #{name} do", force: true

          @in_group = true
          instance_eval(&block)
          @in_group = false

          append_file "Gemfile", "\nend\n", force: true
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
      def add_source(source, options={}, &block)
        log :source, source

        in_root do
          if block
            append_file "Gemfile", "\nsource #{quote(source)} do", force: true
            @in_group = true
            instance_eval(&block)
            @in_group = false
            append_file "Gemfile", "\nend\n", force: true
          else
            prepend_file "Gemfile", "source #{quote(source)}\n", verbose: false
          end
        end
      end

      # Adds a line inside the Application class for <tt>config/application.rb</tt>.
      #
      # If options <tt>:env</tt> is specified, the line is appended to the corresponding
      # file in <tt>config/environments</tt>.
      #
      #   environment do
      #     "config.action_controller.asset_host = 'cdn.provider.com'"
      #   end
      #
      #   environment(nil, env: "development") do
      #     "config.action_controller.asset_host = 'localhost:3000'"
      #   end
      def environment(data=nil, options={})
        sentinel = /class [a-z_:]+ < Rails::Application/i
        env_file_sentinel = /Rails\.application\.configure do/
        data = yield if !data && block_given?

        in_root do
          if options[:env].nil?
            inject_into_file "config/application.rb", "\n    #{data}", after: sentinel, verbose: false
          else
            Array(options[:env]).each do |env|
              inject_into_file "config/environments/#{env}.rb", "\n  #{data}", after: env_file_sentinel, verbose: false
            end
          end
        end
      end
      alias :application :environment

      # Run a command in git.
      #
      #   git :init
      #   git add: "this.file that.rb"
      #   git add: "onefile.rb", rm: "badfile.cxx"
      def git(commands={})
        if commands.is_a?(Symbol)
          run "git #{commands}"
        else
          commands.each do |cmd, options|
            run "git #{cmd} #{options}"
          end
        end
      end

      # Create a new file in the <tt>vendor/</tt> directory. Code can be specified
      # in a block or a data string can be given.
      #
      #   vendor("sekrit.rb") do
      #     sekrit_salt = "#{Time.now}--#{3.years.ago}--#{rand}--"
      #     "salt = '#{sekrit_salt}'"
      #   end
      #
      #   vendor("foreign.rb", "# Foreign code is fun")
      def vendor(filename, data=nil, &block)
        log :vendor, filename
        create_file("vendor/#{filename}", data, verbose: false, &block)
      end

      # Create a new file in the lib/ directory. Code can be specified
      # in a block or a data string can be given.
      #
      #   lib("crypto.rb") do
      #     "crypted_special_value = '#{rand}--#{Time.now}--#{rand(1337)}--'"
      #   end
      #
      #   lib("foreign.rb", "# Foreign code is fun")
      def lib(filename, data=nil, &block)
        log :lib, filename
        create_file("lib/#{filename}", data, verbose: false, &block)
      end

      # Create a new +Rakefile+ with the provided code (either in a block or a string).
      #
      #   rakefile("bootstrap.rake") do
      #     project = ask("What is the UNIX name of your project?")
      #
      #     <<-TASK
      #       namespace :#{project} do
      #         task :bootstrap do
      #           puts "I like boots!"
      #         end
      #       end
      #     TASK
      #   end
      #
      #   rakefile('seed.rake', 'puts "Planting seeds"')
      def rakefile(filename, data=nil, &block)
        log :rakefile, filename
        create_file("lib/tasks/#{filename}", data, verbose: false, &block)
      end

      # Create a new initializer with the provided code (either in a block or a string).
      #
      #   initializer("globals.rb") do
      #     data = ""
      #
      #     ['MY_WORK', 'ADMINS', 'BEST_COMPANY_EVAR'].each do |const|
      #       data << "#{const} = :entp\n"
      #     end
      #
      #     data
      #   end
      #
      #   initializer("api.rb", "API_KEY = '123456'")
      def initializer(filename, data=nil, &block)
        log :initializer, filename
        create_file("config/initializers/#{filename}", data, verbose: false, &block)
      end

      # Generate something using a generator from Rails or a plugin.
      # The second parameter is the argument string that is passed to
      # the generator or an Array that is joined.
      #
      #   generate(:authenticated, "user session")
      def generate(what, *args)
        log :generate, what
        argument = args.flat_map(&:to_s).join(" ")

        in_root { run_ruby_script("bin/rails generate #{what} #{argument}", verbose: false) }
      end

      # Runs the supplied rake task (invoked with 'rake ...')
      #
      #   rake("db:migrate")
      #   rake("db:migrate", env: "production")
      #   rake("gems:install", sudo: true)
      def rake(command, options={})
        execute_command :rake, command, options
      end

      # Runs the supplied rake task (invoked with 'rails ...')
      #
      #   rails("db:migrate")
      #   rails("db:migrate", env: "production")
      #   rails("gems:install", sudo: true)
      def rails_command(command, options={})
        execute_command :rails, command, options
      end

      # Just run the capify command in root
      #
      #   capify!
      def capify!
        log :capify, ""
        in_root { run("#{extify(:capify)} .", verbose: false) }
      end

      # Make an entry in Rails routing file <tt>config/routes.rb</tt>
      #
      #   route "root 'welcome#index'"
      def route(routing_code)
        log :route, routing_code
        sentinel = /\.routes\.draw do\s*\n/m

        in_root do
          inject_into_file "config/routes.rb", "  #{routing_code}\n", { after: sentinel, verbose: false, force: false }
        end
      end

      # Reads the given file at the source root and prints it in the console.
      #
      #   readme "README"
      def readme(path)
        log File.read(find_in_source_paths(path))
      end

      # Registers a callback to be executed after bundle and spring binstubs
      # have run.
      #
      #   after_bundle do
      #     git add: '.'
      #   end
      def after_bundle(&block)
        @after_bundle_callbacks << block
      end

      protected

        # Define log for backwards compatibility. If just one argument is sent,
        # invoke say, otherwise invoke say_status. Differently from say and
        # similarly to say_status, this method respects the quiet? option given.
        def log(*args)
          if args.size == 1
            say args.first.to_s unless options.quiet?
          else
            args << (self.behavior == :invoke ? :green : :red)
            say_status(*args)
          end
        end


        # Runs the supplied command using either "rake ..." or "rails ..."
        # based on the executor parameter provided.
        def execute_command(executor, command, options={})
          log executor, command
          env  = options[:env] || ENV["RAILS_ENV"] || "development"
          sudo = options[:sudo] && RbConfig::CONFIG["host_os"] !~ /mswin|mingw/ ? "sudo " : ""
          in_root { run("#{sudo}#{extify(executor)} #{command} RAILS_ENV=#{env}", verbose: false) }
        end

        # Add an extension to the given name based on the platform.
        def extify(name)
          if RbConfig::CONFIG["host_os"] =~ /mswin|mingw/
            "#{name}.bat"
          else
            name
          end
        end

        # Surround string with single quotes if there is no quotes.
        # Otherwise fall back to double quotes
        def quote(value)
          return value.inspect unless value.is_a? String

          if value.include?("'")
            value.inspect
          else
            "'#{value}'"
          end
        end
    end
  end
end
