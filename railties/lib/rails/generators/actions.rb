require 'open-uri'
require 'rbconfig'

module Rails
  module Generators
    module Actions
      def initialize(*) # :nodoc:
        super
        @in_group = nil
      end

      # Adds an entry into Gemfile for the supplied gem.
      #
      #   gem "rspec", group: :test
      #   gem "technoweenie-restful-authentication", lib: "restful-authentication", source: "http://gems.github.com/"
      #   gem "rails", "3.0", git: "git://github.com/rails/rails"
      def gem(*args)
        options = args.extract_options!
        name, version = args

        # Set the message to be shown in logs. Uses the git repo if one is given,
        # otherwise use name (version).
        parts, message = [ name.inspect ], name
        if version ||= options.delete(:version)
          parts   << version.inspect
          message << " (#{version})"
        end
        message = options[:git] if options[:git]

        log :gemfile, message

        options.each do |option, value|
          parts << "#{option}: #{value.inspect}"
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

      # Add the given source to Gemfile
      #
      #   add_source "http://gems.github.com/"
      def add_source(source, options={})
        log :source, source

        in_root do
          prepend_file "Gemfile", "source #{source.inspect}\n", verbose: false
        end
      end

      # Adds a line inside the Application class for config/application.rb.
      #
      # If options :env is specified, the line is appended to the corresponding
      # file in config/environments.
      #
      #   environment do
      #     "config.autoload_paths += %W(#{config.root}/extras)"
      #   end
      #
      #   environment(nil, env: "development") do
      #     "config.autoload_paths += %W(#{config.root}/extras)"
      #   end
      def environment(data=nil, options={}, &block)
        sentinel = /class [a-z_:]+ < Rails::Application/i
        env_file_sentinel = /::Application\.configure do/
        data = block.call if !data && block_given?

        in_root do
          if options[:env].nil?
            inject_into_file 'config/application.rb', "\n    #{data}", after: sentinel, verbose: false
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

      # Create a new file in the vendor/ directory. Code can be specified
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

      # Create a new Rakefile with the provided code (either in a block or a string).
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
        argument = args.map {|arg| arg.to_s }.flatten.join(" ")

        in_root { run_ruby_script("bin/rails generate #{what} #{argument}", verbose: false) }
      end

      # Runs the supplied rake task
      #
      #   rake("db:migrate")
      #   rake("db:migrate", env: "production")
      #   rake("gems:install", sudo: true)
      def rake(command, options={})
        log :rake, command
        env  = options[:env] || ENV["RAILS_ENV"] || 'development'
        sudo = options[:sudo] && RbConfig::CONFIG['host_os'] !~ /mswin|mingw/ ? 'sudo ' : ''
        in_root { run("#{sudo}#{extify(:rake)} #{command} RAILS_ENV=#{env}", verbose: false) }
      end

      # Just run the capify command in root
      #
      #   capify!
      def capify!
        log :capify, ""
        in_root { run("#{extify(:capify)} .", verbose: false) }
      end

      # Make an entry in Rails routing file config/routes.rb
      #
      #   route "root 'welcome#index'"
      def route(routing_code)
        log :route, routing_code
        sentinel = /\.routes\.draw do\s*$/

        in_root do
          inject_into_file 'config/routes.rb', "\n  #{routing_code}", { after: sentinel, verbose: false }
        end
      end

      # Reads the given file at the source root and prints it in the console.
      #
      #   readme "README"
      def readme(path)
        log File.read(find_in_source_paths(path))
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

        # Add an extension to the given name based on the platform.
        def extify(name)
          if RbConfig::CONFIG['host_os'] =~ /mswin|mingw/
            "#{name}.bat"
          else
            name
          end
        end

    end
  end
end
