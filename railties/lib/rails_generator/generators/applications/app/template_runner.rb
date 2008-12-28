require File.dirname(__FILE__) + '/scm/scm'
require File.dirname(__FILE__) + '/scm/git'
require File.dirname(__FILE__) + '/scm/svn'

require 'open-uri'
require 'fileutils'

module Rails
  class TemplateRunner
    attr_reader :root
    attr_writer :logger

    def initialize(template, root = '') # :nodoc:
      @root = File.expand_path(File.directory?(root) ? root : File.join(Dir.pwd, root))

      log 'applying', "template: #{template}"

      load_template(template)

      log 'applied', "#{template}"
    end

    def load_template(template)
      begin
        code = open(template).read
        in_root { self.instance_eval(code) }
      rescue LoadError, Errno::ENOENT => e
        raise "The template [#{template}] could not be loaded. Error: #{e}"
      end
    end

    # Create a new file in the Rails project folder.  Specify the
    # relative path from RAILS_ROOT.  Data is the return value of a block
    # or a data string.
    #
    # ==== Examples
    #
    #   file("lib/fun_party.rb") do
    #     hostname = ask("What is the virtual hostname I should use?")
    #     "vhost.name = #{hostname}"
    #   end
    #
    #   file("config/apach.conf", "your apache config")
    #
    def file(filename, data = nil, log_action = true, &block)
      log 'file', filename if log_action
      dir, file = [File.dirname(filename), File.basename(filename)]

      inside(dir) do
        File.open(file, "w") do |f|
          if block_given?
            f.write(block.call)
          else
            f.write(data)
          end
        end
      end
    end

    # Install a plugin.  You must provide either a Subversion url or Git url.
    # For a Git-hosted plugin, you can specify if it should be added as a submodule instead of cloned.
    #
    # ==== Examples
    #
    #   plugin 'restful-authentication', :git => 'git://github.com/technoweenie/restful-authentication.git'
    #   plugin 'restful-authentication', :git => 'git://github.com/technoweenie/restful-authentication.git', :submodule => true
    #   plugin 'restful-authentication', :svn => 'svn://svnhub.com/technoweenie/restful-authentication/trunk'
    #
    def plugin(name, options)
      log 'plugin', name

      if options[:git] && options[:submodule]
        in_root do
          Git.run("submodule add #{options[:git]} vendor/plugins/#{name}")
        end
      elsif options[:git] || options[:svn]
        in_root do
          run("script/plugin install #{options[:svn] || options[:git]}", false)
        end
      else
        log "! no git or svn provided for #{name}.  skipping..."
      end
    end

    # Adds an entry into config/environment.rb for the supplied gem :
    def gem(name, options = {})
      log 'gem', name

      gems_code = "config.gem '#{name}'"

      if options.any?
        opts = options.inject([]) {|result, h| result << [":#{h[0]} => '#{h[1]}'"] }.sort.join(", ")
        gems_code << ", #{opts}"
      end

      environment gems_code
    end

    # Adds a line inside the Initializer block for config/environment.rb. Used by #gem
    def environment(data = nil, &block)
      sentinel = 'Rails::Initializer.run do |config|'

      data = block.call if !data && block_given?

      in_root do
        gsub_file 'config/environment.rb', /(#{Regexp.escape(sentinel)})/mi do |match|
          "#{match}\n " << data
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
          log 'running', "git #{command}"
          Git.run(command.to_s)
        else
          command.each do |command, options|
            log 'running', "git #{command} #{options}"
            Git.run("#{command} #{options}")
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
    def vendor(filename, data = nil, &block)
      log 'vendoring', filename
      file("vendor/#{filename}", data, false, &block)
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
    def lib(filename, data = nil, &block)
      log 'lib', filename
      file("lib/#{filename}", data, false, &block)
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
    def rakefile(filename, data = nil, &block)
      log 'rakefile', filename
      file("lib/tasks/#{filename}", data, false, &block)
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
    def initializer(filename, data = nil, &block)
      log 'initializer', filename
      file("config/initializers/#{filename}", data, false, &block)
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
      log 'generating', what
      argument = args.map(&:to_s).flatten.join(" ")

      in_root { run("script/generate #{what} #{argument}", false) }
    end

    # Executes a command
    #
    # ==== Example
    #
    #   inside('vendor') do
    #     run('ln -s ~/edge rails)
    #   end
    #
    def run(command, log_action = true)
      log 'executing',  "#{command} from #{Dir.pwd}" if log_action
      `#{command}`
    end

    # Runs the supplied rake task
    #
    # ==== Example
    #
    #   rake("db:migrate")
    #   rake("db:migrate", :env => "production")
    #   rake("gems:install", :sudo => true)
    #
    def rake(command, options = {})
      log 'rake', command
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
      log 'capifying'
      in_root { run('capify .', false) }
    end

    # Add Rails to /vendor/rails
    #
    # ==== Example
    #
    #   freeze!
    #
    def freeze!(args = {})
      log 'vendor', 'rails edge'
      in_root { run('rake rails:freeze:edge', false) }
    end

    # Make an entry in Rails routing file conifg/routes.rb
    #
    # === Example
    #
    #   route "map.root :controller => :welcome"
    #
    def route(routing_code)
      log 'route', routing_code
      sentinel = 'ActionController::Routing::Routes.draw do |map|'

      in_root do
        gsub_file 'config/routes.rb', /(#{Regexp.escape(sentinel)})/mi do |match|
          "#{match}\n  #{routing_code}\n"
        end
      end
    end

    protected

    # Get a user's input
    #
    # ==== Example
    #
    #   answer = ask("Should I freeze the latest Rails?")
    #   freeze! if ask("Should I freeze the latest Rails?") == "yes"
    #
    def ask(string)
      log '', string
      gets.strip
    end

    # Do something in the root of the Rails application or
    # a provided subfolder; the full path is yielded to the block you provide.
    # The path is set back to the previous path when the method exits.
    def inside(dir = '', &block)
      folder = File.join(root, dir)
      FileUtils.mkdir_p(folder) unless File.exist?(folder)
      FileUtils.cd(folder) { block.arity == 1 ? yield(folder) : yield }
    end

    def in_root
      FileUtils.cd(root) { yield }
    end

    # Helper to test if the user says yes(y)?
    #
    # ==== Example
    #
    #   freeze! if yes?("Should I freeze the latest Rails?")
    #
    def yes?(question)
      answer = ask(question).downcase
      answer == "y" || answer == "yes"
    end

    # Helper to test if the user does NOT say yes(y)?
    #
    # ==== Example
    #
    #   capify! if no?("Will you be using vlad to deploy your application?")
    #
    def no?(question)
      !yes?(question)
    end

    # Run a regular expression replacement on a file
    #
    # ==== Example
    #
    #   gsub_file 'app/controllers/application_controller.rb', /#\s*(filter_parameter_logging :password)/, '\1'
    #
    def gsub_file(relative_destination, regexp, *args, &block)
      path = destination_path(relative_destination)
      content = File.read(path).gsub(regexp, *args, &block)
      File.open(path, 'wb') { |file| file.write(content) }
    end

    def destination_path(relative_destination)
      File.join(root, relative_destination)
    end

    def log(action, message = '')
      logger.log(action, message)
    end

    def logger
      @logger ||= Rails::Generator::Base.logger
    end

    def logger
      @logger ||= if defined?(Rails::Generator::Base)
        Rails::Generator::Base.logger
      else
        require 'rails_generator/simple_logger'
        Rails::Generator::SimpleLogger.new(STDOUT)
      end
    end

  end
end
