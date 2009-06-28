require 'open-uri'

module Rails
  module Generators
    module Actions

      # Loads an external file and execute it in the instance binding.
      #
      # ==== Parameters
      # path<String>:: The path to the file to execute. Can be a web address or
      #                a relative path from the source root.
      #
      # ==== Examples
      #
      #   apply "http://gist.github.com/103208"
      #
      #   apply "recipes/jquery.rb"
      #
      def apply(path, log_status=true)
        path = File.expand_path(path, source_root) unless path =~ /^http\:\/\//

        log :apply, path, log_status
        instance_eval(open(path).read)
        log :applied, path, log_status
      end

      # Install a plugin. You must provide either a Subversion url or Git url.
      # For a Git-hosted plugin, you can specify if it should be added as a submodule instead of cloned.
      #
      # ==== Examples
      #
      #   plugin 'restful-authentication', :git => 'git://github.com/technoweenie/restful-authentication.git'
      #   plugin 'restful-authentication', :git => 'git://github.com/technoweenie/restful-authentication.git', :submodule => true
      #   plugin 'restful-authentication', :svn => 'svn://svnhub.com/technoweenie/restful-authentication/trunk'
      #
      def plugin(name, options)
        log :plugin, name

        if options[:git] && options[:submodule]
          in_root do
            run "git submodule add #{options[:git]} vendor/plugins/#{name}", false
          end
        elsif options[:git] || options[:svn]
          in_root do
            run_ruby_script "script/plugin install #{options[:svn] || options[:git]}", false
          end
        else
          log "! no git or svn provided for #{name}. Skipping..."
        end
      end

      # Adds an entry into config/environment.rb for the supplied gem. If env
      # is specified, add the gem to the given environment.
      #
      # ==== Example
      #
      #   gem "rspec", :env => :test
      #   gem "technoweenie-restful-authentication", :lib => "restful-authentication", :source => "http://gems.github.com/"
      #
      def gem(name, options = {})
        log :gem, name
        env = options.delete(:env)

        gems_code = "config.gem '#{name}'"

        if options.any?
          opts = options.inject([]) {|result, h| result << [":#{h[0]} => #{h[1].inspect.gsub('"',"'")}"] }.sort.join(", ")
          gems_code << ", #{opts}"
        end

        environment gems_code, :env => env
      end

      # Adds a line inside the Initializer block for config/environment.rb.
      #
      # If options :env is specified, the line is appended to the corresponding
      # file in config/environments.
      #
      def environment(data=nil, options={}, &block)
        sentinel = "Rails::Initializer.run do |config|"

        data = block.call if !data && block_given?

        in_root do
          if options[:env].nil?
            inject_into_file 'config/environment.rb', "\n  #{data}", { :after => sentinel }, false
          else
            Array.wrap(options[:env]).each do|env|
              append_file "config/environments/#{env}.rb", "\n#{data}", false
            end
          end
        end
      end

      # Run a command in git.
      #
      # ==== Examples
      #
      #   git :init
      #   git :add => "this.file that.rb"
      #   git :add => "onefile.rb", :rm => "badfile.cxx"
      #
      def git(command = {})
        in_root do
          if command.is_a?(Symbol)
            run "git #{command}"
          else
            command.each do |command, options|
              run "git #{command} #{options}"
            end
          end
        end
      end

      # Create a new file in the vendor/ directory. Code can be specified
      # in a block or a data string can be given.
      #
      # ==== Examples
      #
      #   vendor("sekrit.rb") do
      #     sekrit_salt = "#{Time.now}--#{3.years.ago}--#{rand}--"
      #     "salt = '#{sekrit_salt}'"
      #   end
      #
      #   vendor("foreign.rb", "# Foreign code is fun")
      #
      def vendor(filename, data=nil, &block)
        log :vendor, filename
        create_file("vendor/#{filename}", data, false, &block)
      end

      # Create a new file in the lib/ directory. Code can be specified
      # in a block or a data string can be given.
      #
      # ==== Examples
      #
      #   lib("crypto.rb") do
      #     "crypted_special_value = '#{rand}--#{Time.now}--#{rand(1337)}--'"
      #   end
      #
      #   lib("foreign.rb", "# Foreign code is fun")
      #
      def lib(filename, data=nil, &block)
        log :lib, filename
        create_file("lib/#{filename}", data, false, &block)
      end

      # Create a new Rakefile with the provided code (either in a block or a string).
      #
      # ==== Examples
      #
      #   rakefile("bootstrap.rake") do
      #     project = ask("What is the UNIX name of your project?")
      #
      #     <<-TASK
      #       namespace :#{project} do
      #         task :bootstrap do
      #           puts "i like boots!"
      #         end
      #       end
      #     TASK
      #   end
      #
      #   rakefile("seed.rake", "puts 'im plantin ur seedz'")
      #
      def rakefile(filename, data=nil, &block)
        log :rakefile, filename
        create_file("lib/tasks/#{filename}", data, false, &block)
      end

      # Create a new initializer with the provided code (either in a block or a string).
      #
      # ==== Examples
      #
      #   initializer("globals.rb") do
      #     data = ""
      #
      #     ['MY_WORK', 'ADMINS', 'BEST_COMPANY_EVAR'].each do
      #       data << "#{const} = :entp"
      #     end
      #
      #     data
      #   end
      #
      #   initializer("api.rb", "API_KEY = '123456'")
      #
      def initializer(filename, data=nil, &block)
        log :initializer, filename
        create_file("config/initializers/#{filename}", data, false, &block)
      end

      # Generate something using a generator from Rails or a plugin.
      # The second parameter is the argument string that is passed to
      # the generator or an Array that is joined.
      #
      # ==== Example
      #
      #   generate(:authenticated, "user session")
      #
      def generate(what, *args)
        log :generate, what
        argument = args.map {|arg| arg.to_s }.flatten.join(" ")

        in_root { run_ruby_script("script/generate #{what} #{argument}", false) }
      end

      # Runs the supplied rake task
      #
      # ==== Example
      #
      #   rake("db:migrate")
      #   rake("db:migrate", :env => "production")
      #   rake("gems:install", :sudo => true)
      #
      def rake(command, options={})
        log :rake, command
        env = options[:env] || 'development'
        sudo = options[:sudo] ? 'sudo ' : ''
        in_root { run("#{sudo}rake #{command} RAILS_ENV=#{env}", false) }
      end

      # Just run the capify command in root
      #
      # ==== Example
      #
      #   capify!
      #
      def capify!
        log :capify, ""
        in_root { run('capify .', false) }
      end

      # Add Rails to /vendor/rails
      #
      # ==== Example
      #
      #   freeze!
      #
      def freeze!(args = {})
        log :vendor, "rails"
        in_root { run('rake rails:freeze:edge', false) }
      end

      # Make an entry in Rails routing file conifg/routes.rb
      #
      # === Example
      #
      #   route "map.root :controller => :welcome"
      #
      def route(routing_code)
        log :route, routing_code
        sentinel = "ActionController::Routing::Routes.draw do |map|"

        in_root do
          inject_into_file 'config/routes.rb', "\n  #{routing_code}\n", { :after => sentinel }, false
        end
      end

      protected

        # Define log for backwards compatibility. If just one argument is sent,
        # invoke say, otherwise invoke say_status.
        #
        def log(*args)
          if args.size == 1
            say args.first.to_s
          else
            say_status *args
          end
        end

    end
  end
end
