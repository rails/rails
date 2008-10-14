require 'delegate'
require 'optparse'
require 'fileutils'
require 'tempfile'
require 'erb'

module Rails
  module Generator
    module Commands
      # Here's a convenient way to get a handle on generator commands.
      # Command.instance('destroy', my_generator) instantiates a Destroy
      # delegate of my_generator ready to do your dirty work.
      def self.instance(command, generator)
        const_get(command.to_s.camelize).new(generator)
      end

      # Even more convenient access to commands.  Include Commands in
      # the generator Base class to get a nice #command instance method
      # which returns a delegate for the requested command.
      def self.included(base)
        base.send(:define_method, :command) do |command|
          Commands.instance(command, self)
        end
      end


      # Generator commands delegate Rails::Generator::Base and implement
      # a standard set of actions.  Their behavior is defined by the way
      # they respond to these actions: Create brings life; Destroy brings
      # death; List passively observes.
      #
      # Commands are invoked by replaying (or rewinding) the generator's
      # manifest of actions.  See Rails::Generator::Manifest and
      # Rails::Generator::Base#manifest method that generator subclasses
      # are required to override.
      #
      # Commands allows generators to "plug in" invocation behavior, which
      # corresponds to the GoF Strategy pattern.
      class Base < DelegateClass(Rails::Generator::Base)
        # Replay action manifest.  RewindBase subclass rewinds manifest.
        def invoke!
          manifest.replay(self)
        end

        def dependency(generator_name, args, runtime_options = {})
          logger.dependency(generator_name) do
            self.class.new(instance(generator_name, args, full_options(runtime_options))).invoke!
          end
        end

        # Does nothing for all commands except Create.
        def class_collisions(*class_names)
        end

        # Does nothing for all commands except Create.
        def readme(*args)
        end

        protected
          def current_migration_number
            Dir.glob("#{RAILS_ROOT}/#{@migration_directory}/[0-9]*_*.rb").inject(0) do |max, file_path|
              n = File.basename(file_path).split('_', 2).first.to_i
              if n > max then n else max end
            end
          end
             
          def next_migration_number
            current_migration_number + 1
          end
               
          def migration_directory(relative_path)
            directory(@migration_directory = relative_path)
          end

          def existing_migrations(file_name)
            Dir.glob("#{@migration_directory}/[0-9]*_*.rb").grep(/[0-9]+_#{file_name}.rb$/)
          end

          def migration_exists?(file_name)
            not existing_migrations(file_name).empty?
          end

          def next_migration_string(padding = 3)
            if ActiveRecord::Base.timestamped_migrations
              Time.now.utc.strftime("%Y%m%d%H%M%S")
            else
              "%.#{padding}d" % next_migration_number
            end
          end

          def gsub_file(relative_destination, regexp, *args, &block)
            path = destination_path(relative_destination)
            content = File.read(path).gsub(regexp, *args, &block)
            File.open(path, 'wb') { |file| file.write(content) }
          end

        private
          # Ask the user interactively whether to force collision.
          def force_file_collision?(destination, src, dst, file_options = {}, &block)
            $stdout.print "overwrite #{destination}? (enter \"h\" for help) [Ynaqdh] "
            case $stdin.gets.chomp
              when /\Ad\z/i
                Tempfile.open(File.basename(destination), File.dirname(dst)) do |temp|
                  temp.write render_file(src, file_options, &block)
                  temp.rewind
                  $stdout.puts `#{diff_cmd} "#{dst}" "#{temp.path}"`
                end
                puts "retrying"
                raise 'retry diff'
              when /\Aa\z/i
                $stdout.puts "forcing #{spec.name}"
                options[:collision] = :force
              when /\Aq\z/i
                $stdout.puts "aborting #{spec.name}"
                raise SystemExit
              when /\An\z/i then :skip
              when /\Ay\z/i then :force
              else
                $stdout.puts <<-HELP
Y - yes, overwrite
n - no, do not overwrite
a - all, overwrite this and all others
q - quit, abort
d - diff, show the differences between the old and the new
h - help, show this help
HELP
                raise 'retry'
            end
          rescue
            retry
          end

          def diff_cmd
            ENV['RAILS_DIFF'] || 'diff -u'
          end

          def render_template_part(template_options)
            # Getting Sandbox to evaluate part template in it
            part_binding = template_options[:sandbox].call.sandbox_binding
            part_rel_path = template_options[:insert]
            part_path = source_path(part_rel_path)

            # Render inner template within Sandbox binding
            rendered_part = ERB.new(File.readlines(part_path).join, nil, '-').result(part_binding)
            begin_mark = template_part_mark(template_options[:begin_mark], template_options[:mark_id])
            end_mark = template_part_mark(template_options[:end_mark], template_options[:mark_id])
            begin_mark + rendered_part + end_mark
          end

          def template_part_mark(name, id)
            "<!--[#{name}:#{id}]-->\n"
          end
      end

      # Base class for commands which handle generator actions in reverse, such as Destroy.
      class RewindBase < Base
        # Rewind action manifest.
        def invoke!
          manifest.rewind(self)
        end
      end


      # Create is the premier generator command.  It copies files, creates
      # directories, renders templates, and more.
      class Create < Base

        # Check whether the given class names are already taken by
        # Ruby or Rails.  In the future, expand to check other namespaces
        # such as the rest of the user's app.
        def class_collisions(*class_names)
          path = class_names.shift
          class_names.flatten.each do |class_name|
            # Convert to string to allow symbol arguments.
            class_name = class_name.to_s

            # Skip empty strings.
            next if class_name.strip.empty?

            # Split the class from its module nesting.
            nesting = class_name.split('::')
            name = nesting.pop

            # Extract the last Module in the nesting.
            last = nesting.inject(Object) { |last, nest|
              break unless last.const_defined?(nest)
              last.const_get(nest)
            }

            # If the last Module exists, check whether the given
            # class exists and raise a collision if so.
            if last and last.const_defined?(name.camelize)
              raise_class_collision(class_name)
            end
          end
        end

        # Copy a file from source to destination with collision checking.
        #
        # The file_options hash accepts :chmod and :shebang and :collision options.
        # :chmod sets the permissions of the destination file:
        #   file 'config/empty.log', 'log/test.log', :chmod => 0664
        # :shebang sets the #!/usr/bin/ruby line for scripts
        #   file 'bin/generate.rb', 'script/generate', :chmod => 0755, :shebang => '/usr/bin/env ruby'
        # :collision sets the collision option only for the destination file:
        #   file 'settings/server.yml', 'config/server.yml', :collision => :skip
        #
        # Collisions are handled by checking whether the destination file
        # exists and either skipping the file, forcing overwrite, or asking
        # the user what to do.
        def file(relative_source, relative_destination, file_options = {}, &block)
          # Determine full paths for source and destination files.
          source              = source_path(relative_source)
          destination         = destination_path(relative_destination)
          destination_exists  = File.exist?(destination)

          # If source and destination are identical then we're done.
          if destination_exists and identical?(source, destination, &block)
            return logger.identical(relative_destination)
          end

          # Check for and resolve file collisions.
          if destination_exists

            # Make a choice whether to overwrite the file.  :force and
            # :skip already have their mind made up, but give :ask a shot.
            choice = case (file_options[:collision] || options[:collision]).to_sym #|| :ask
              when :ask   then force_file_collision?(relative_destination, source, destination, file_options, &block)
              when :force then :force
              when :skip  then :skip
              else raise "Invalid collision option: #{options[:collision].inspect}"
            end

            # Take action based on our choice.  Bail out if we chose to
            # skip the file; otherwise, log our transgression and continue.
            case choice
              when :force then logger.force(relative_destination)
              when :skip  then return(logger.skip(relative_destination))
              else raise "Invalid collision choice: #{choice}.inspect"
            end

          # File doesn't exist so log its unbesmirched creation.
          else
            logger.create relative_destination
          end

          # If we're pretending, back off now.
          return if options[:pretend]

          # Write destination file with optional shebang.  Yield for content
          # if block given so templaters may render the source file.  If a
          # shebang is requested, replace the existing shebang or insert a
          # new one.
          File.open(destination, 'wb') do |dest|
            dest.write render_file(source, file_options, &block)
          end

          # Optionally change permissions.
          if file_options[:chmod]
            FileUtils.chmod(file_options[:chmod], destination)
          end

          # Optionally add file to subversion or git
          system("svn add #{destination}") if options[:svn]
          system("git add -v #{relative_destination}") if options[:git]
        end

        # Checks if the source and the destination file are identical. If
        # passed a block then the source file is a template that needs to first
        # be evaluated before being compared to the destination.
        def identical?(source, destination, &block)
          return false if File.directory? destination
          source      = block_given? ? File.open(source) {|sf| yield(sf)} : IO.read(source)
          destination = IO.read(destination)
          source == destination
        end

        # Generate a file for a Rails application using an ERuby template.
        # Looks up and evaluates a template by name and writes the result.
        #
        # The ERB template uses explicit trim mode to best control the
        # proliferation of whitespace in generated code.  <%- trims leading
        # whitespace; -%> trims trailing whitespace including one newline.
        #
        # A hash of template options may be passed as the last argument.
        # The options accepted by the file are accepted as well as :assigns,
        # a hash of variable bindings.  Example:
        #   template 'foo', 'bar', :assigns => { :action => 'view' }
        #
        # Template is implemented in terms of file.  It calls file with a
        # block which takes a file handle and returns its rendered contents.
        def template(relative_source, relative_destination, template_options = {})
          file(relative_source, relative_destination, template_options) do |file|
            # Evaluate any assignments in a temporary, throwaway binding.
            vars = template_options[:assigns] || {}
            b = binding
            vars.each { |k,v| eval "#{k} = vars[:#{k}] || vars['#{k}']", b }

            # Render the source file with the temporary binding.
            ERB.new(file.read, nil, '-').result(b)
          end
        end

        def complex_template(relative_source, relative_destination, template_options = {})
          options = template_options.dup
          options[:assigns] ||= {}
          options[:assigns]['template_for_inclusion'] = render_template_part(template_options)
          template(relative_source, relative_destination, options)
        end

        # Create a directory including any missing parent directories.
        # Always skips directories which exist.
        def directory(relative_path)
          path = destination_path(relative_path)
          if File.exist?(path)
            logger.exists relative_path
          else
            logger.create relative_path
            unless options[:pretend]
              FileUtils.mkdir_p(path)
              # git doesn't require adding the paths, adding the files later will
              # automatically do a path add.

              # Subversion doesn't do path adds, so we need to add
              # each directory individually.
              # So stack up the directory tree and add the paths to
              # subversion in order without recursion.
              if options[:svn]
                stack = [relative_path]
                until File.dirname(stack.last) == stack.last # dirname('.') == '.'
                  stack.push File.dirname(stack.last)
                end
                stack.reverse_each do |rel_path|
                  svn_path = destination_path(rel_path)
                  system("svn add -N #{svn_path}") unless File.directory?(File.join(svn_path, '.svn'))
                end
              end
            end
          end
        end

        # Display a README.
        def readme(*relative_sources)
          relative_sources.flatten.each do |relative_source|
            logger.readme relative_source
            puts File.read(source_path(relative_source)) unless options[:pretend]
          end
        end

        # When creating a migration, it knows to find the first available file in db/migrate and use the migration.rb template.
        def migration_template(relative_source, relative_destination, template_options = {})
          migration_directory relative_destination
          migration_file_name = template_options[:migration_file_name] || file_name
          raise "Another migration is already named #{migration_file_name}: #{existing_migrations(migration_file_name).first}" if migration_exists?(migration_file_name)
          template(relative_source, "#{relative_destination}/#{next_migration_string}_#{migration_file_name}.rb", template_options)
        end

        def route_resources(*resources)
          resource_list = resources.map { |r| r.to_sym.inspect }.join(', ')
          sentinel = 'ActionController::Routing::Routes.draw do |map|'

          logger.route "map.resources #{resource_list}"
          unless options[:pretend]
            gsub_file 'config/routes.rb', /(#{Regexp.escape(sentinel)})/mi do |match|
              "#{match}\n  map.resources #{resource_list}\n"
            end
          end
        end

        private
          def render_file(path, options = {})
            File.open(path, 'rb') do |file|
              if block_given?
                yield file
              else
                content = ''
                if shebang = options[:shebang]
                  content << "#!#{shebang}\n"
                  if line = file.gets
                    content << "line\n" if line !~ /^#!/
                  end
                end
                content << file.read
              end
            end
          end

          # Raise a usage error with an informative WordNet suggestion.
          # Thanks to Florian Gross (flgr).
          def raise_class_collision(class_name)
            message = <<end_message
  The name '#{class_name}' is either already used in your application or reserved by Ruby on Rails.
  Please choose an alternative and run this generator again.
end_message
            if suggest = find_synonyms(class_name)
              if suggest.any?
                message << "\n  Suggestions:  \n\n"
                message << suggest.join("\n")
              end
            end
            raise UsageError, message
          end

          SYNONYM_LOOKUP_URI = "http://wordnet.princeton.edu/perl/webwn?s=%s"

          # Look up synonyms on WordNet.  Thanks to Florian Gross (flgr).
          def find_synonyms(word)
            require 'open-uri'
            require 'timeout'
            timeout(5) do
              open(SYNONYM_LOOKUP_URI % word) do |stream|
                # Grab words linked to dictionary entries as possible synonyms
                data = stream.read.gsub("&nbsp;", " ").scan(/<a href="webwn.*?">([\w ]*?)<\/a>/s).uniq
              end
            end
          rescue Exception
            return nil
          end
      end


      # Undo the actions performed by a generator.  Rewind the action
      # manifest and attempt to completely erase the results of each action.
      class Destroy < RewindBase
        # Remove a file if it exists and is a file.
        def file(relative_source, relative_destination, file_options = {})
          destination = destination_path(relative_destination)
          if File.exist?(destination)
            logger.rm relative_destination
            unless options[:pretend]
              if options[:svn]
                # If the file has been marked to be added
                # but has not yet been checked in, revert and delete
                if options[:svn][relative_destination]
                  system("svn revert #{destination}")
                  FileUtils.rm(destination)
                else
                # If the directory is not in the status list, it
                # has no modifications so we can simply remove it
                  system("svn rm #{destination}")
                end
              elsif options[:git]
                if options[:git][:new][relative_destination]
                  # file has been added, but not committed
                  system("git reset HEAD #{relative_destination}")
                  FileUtils.rm(destination)
                elsif options[:git][:modified][relative_destination]
                  # file is committed and modified
                  system("git rm -f #{relative_destination}")
                else
                  # If the directory is not in the status list, it
                  # has no modifications so we can simply remove it
                  system("git rm #{relative_destination}")
                end
              else
                FileUtils.rm(destination)
              end
            end
          else
            logger.missing relative_destination
            return
          end
        end

        # Templates are deleted just like files and the actions take the
        # same parameters, so simply alias the file method.
        alias_method :template, :file

        # Remove each directory in the given path from right to left.
        # Remove each subdirectory if it exists and is a directory.
        def directory(relative_path)
          parts = relative_path.split('/')
          until parts.empty?
            partial = File.join(parts)
            path = destination_path(partial)
            if File.exist?(path)
              if Dir[File.join(path, '*')].empty?
                logger.rmdir partial
                unless options[:pretend]
                  if options[:svn]
                    # If the directory has been marked to be added
                    # but has not yet been checked in, revert and delete
                    if options[:svn][relative_path]
                      system("svn revert #{path}")
                      FileUtils.rmdir(path)
                    else
                    # If the directory is not in the status list, it
                    # has no modifications so we can simply remove it
                      system("svn rm #{path}")
                    end
                  # I don't think git needs to remove directories?..
                  # or maybe they have special consideration...
                  else
                    FileUtils.rmdir(path)
                  end
                end
              else
                logger.notempty partial
              end
            else
              logger.missing partial
            end
            parts.pop
          end
        end

        def complex_template(*args)
          # nothing should be done here
        end

        # When deleting a migration, it knows to delete every file named "[0-9]*_#{file_name}".
        def migration_template(relative_source, relative_destination, template_options = {})
          migration_directory relative_destination

          migration_file_name = template_options[:migration_file_name] || file_name
          unless migration_exists?(migration_file_name)
            puts "There is no migration named #{migration_file_name}"
            return
          end


          existing_migrations(migration_file_name).each do |file_path|
            file(relative_source, file_path, template_options)
          end
        end

        def route_resources(*resources)
          resource_list = resources.map { |r| r.to_sym.inspect }.join(', ')
          look_for = "\n  map.resources #{resource_list}\n"
          logger.route "map.resources #{resource_list}"
          gsub_file 'config/routes.rb', /(#{look_for})/mi, ''
        end
      end


      # List a generator's action manifest.
      class List < Base
        def dependency(generator_name, args, options = {})
          logger.dependency "#{generator_name}(#{args.join(', ')}, #{options.inspect})"
        end

        def class_collisions(*class_names)
          logger.class_collisions class_names.join(', ')
        end

        def file(relative_source, relative_destination, options = {})
          logger.file relative_destination
        end

        def template(relative_source, relative_destination, options = {})
          logger.template relative_destination
        end

        def complex_template(relative_source, relative_destination, options = {})
          logger.template "#{options[:insert]} inside #{relative_destination}"
        end

        def directory(relative_path)
          logger.directory "#{destination_path(relative_path)}/"
        end

        def readme(*args)
          logger.readme args.join(', ')
        end

        def migration_template(relative_source, relative_destination, options = {})
          migration_directory relative_destination
          logger.migration_template file_name
        end

        def route_resources(*resources)
          resource_list = resources.map { |r| r.to_sym.inspect }.join(', ')
          logger.route "map.resources #{resource_list}"
        end
      end

      # Update generator's action manifest.
      class Update < Create
        def file(relative_source, relative_destination, options = {})
          # logger.file relative_destination
        end

        def template(relative_source, relative_destination, options = {})
          # logger.template relative_destination
        end

        def complex_template(relative_source, relative_destination, template_options = {})

           begin
             dest_file = destination_path(relative_destination)
             source_to_update = File.readlines(dest_file).join
           rescue Errno::ENOENT
             logger.missing relative_destination
             return
           end

           logger.refreshing "#{template_options[:insert].gsub(/\.erb/,'')} inside #{relative_destination}"

           begin_mark = Regexp.quote(template_part_mark(template_options[:begin_mark], template_options[:mark_id]))
           end_mark = Regexp.quote(template_part_mark(template_options[:end_mark], template_options[:mark_id]))

           # Refreshing inner part of the template with freshly rendered part.
           rendered_part = render_template_part(template_options)
           source_to_update.gsub!(/#{begin_mark}.*?#{end_mark}/m, rendered_part)

           File.open(dest_file, 'w') { |file| file.write(source_to_update) }
        end

        def directory(relative_path)
          # logger.directory "#{destination_path(relative_path)}/"
        end
      end

    end
  end
end
