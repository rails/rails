require 'erb'
require 'open-uri'

class Thor
  module Actions

    # Copies the file from the relative source to the relative destination. If
    # the destination is not given it's assumed to be equal to the source.
    #
    # ==== Parameters
    # source<String>:: the relative path to the source root.
    # destination<String>:: the relative path to the destination root.
    # config<Hash>:: give :verbose => false to not log the status.
    #
    # ==== Examples
    #
    #   copy_file "README", "doc/README"
    #
    #   copy_file "doc/README"
    #
    def copy_file(source, destination=nil, config={}, &block)
      destination ||= source
      source = File.expand_path(find_in_source_paths(source.to_s))

      create_file destination, nil, config do
        content = File.read(source)
        content = block.call(content) if block
        content
      end
    end

    # Gets the content at the given address and places it at the given relative
    # destination. If a block is given instead of destination, the content of
    # the url is yielded and used as location.
    #
    # ==== Parameters
    # source<String>:: the address of the given content.
    # destination<String>:: the relative path to the destination root.
    # config<Hash>:: give :verbose => false to not log the status.
    #
    # ==== Examples
    #
    #   get "http://gist.github.com/103208", "doc/README"
    #
    #   get "http://gist.github.com/103208" do |content|
    #     content.split("\n").first
    #   end
    #
    def get(source, destination=nil, config={}, &block)
      source = File.expand_path(find_in_source_paths(source.to_s)) unless source =~ /^http\:\/\//
      render = open(source).read

      destination ||= if block_given?
        block.arity == 1 ? block.call(render) : block.call
      else
        File.basename(source)
      end

      create_file destination, render, config
    end

    # Gets an ERB template at the relative source, executes it and makes a copy
    # at the relative destination. If the destination is not given it's assumed
    # to be equal to the source removing .tt from the filename.
    #
    # ==== Parameters
    # source<String>:: the relative path to the source root.
    # destination<String>:: the relative path to the destination root.
    # config<Hash>:: give :verbose => false to not log the status.
    #
    # ==== Examples
    #
    #   template "README", "doc/README"
    #
    #   template "doc/README"
    #
    def template(source, destination=nil, config={}, &block)
      destination ||= source
      source  = File.expand_path(find_in_source_paths(source.to_s))
      context = instance_eval('binding')

      create_file destination, nil, config do
        content = ERB.new(::File.read(source), nil, '-').result(context)
        content = block.call(content) if block
        content
      end
    end

    # Changes the mode of the given file or directory.
    #
    # ==== Parameters
    # mode<Integer>:: the file mode
    # path<String>:: the name of the file to change mode
    # config<Hash>:: give :verbose => false to not log the status.
    #
    # ==== Example
    #
    #   chmod "script/*", 0755
    #
    def chmod(path, mode, config={})
      return unless behavior == :invoke
      path = File.expand_path(path, destination_root)
      say_status :chmod, relative_to_original_destination_root(path), config.fetch(:verbose, true)
      FileUtils.chmod_R(mode, path) unless options[:pretend]
    end

    # Prepend text to a file. Since it depends on inject_into_file, it's reversible.
    #
    # ==== Parameters
    # path<String>:: path of the file to be changed
    # data<String>:: the data to prepend to the file, can be also given as a block.
    # config<Hash>:: give :verbose => false to not log the status.
    #
    # ==== Example
    #
    #   prepend_file 'config/environments/test.rb', 'config.gem "rspec"'
    #
    #   prepend_file 'config/environments/test.rb' do
    #     'config.gem "rspec"'
    #   end
    #
    def prepend_file(path, *args, &block)
      config = args.last.is_a?(Hash) ? args.pop : {}
      config.merge!(:after => /\A/)
      inject_into_file(path, *(args << config), &block)
    end

    # Append text to a file. Since it depends on inject_into_file, it's reversible.
    #
    # ==== Parameters
    # path<String>:: path of the file to be changed
    # data<String>:: the data to append to the file, can be also given as a block.
    # config<Hash>:: give :verbose => false to not log the status.
    #
    # ==== Example
    #
    #   append_file 'config/environments/test.rb', 'config.gem "rspec"'
    #
    #   append_file 'config/environments/test.rb' do
    #     'config.gem "rspec"'
    #   end
    #
    def append_file(path, *args, &block)
      config = args.last.is_a?(Hash) ? args.pop : {}
      config.merge!(:before => /\z/)
      inject_into_file(path, *(args << config), &block)
    end

    # Injects text right after the class definition. Since it depends on
    # inject_into_file, it's reversible.
    #
    # ==== Parameters
    # path<String>:: path of the file to be changed
    # klass<String|Class>:: the class to be manipulated
    # data<String>:: the data to append to the class, can be also given as a block.
    # config<Hash>:: give :verbose => false to not log the status.
    #
    # ==== Examples
    #
    #   inject_into_class "app/controllers/application_controller.rb", "  filter_parameter :password\n"
    #
    #   inject_into_class "app/controllers/application_controller.rb", ApplicationController do
    #     "  filter_parameter :password\n"
    #   end
    #
    def inject_into_class(path, klass, *args, &block)
      config = args.last.is_a?(Hash) ? args.pop : {}
      config.merge!(:after => /class #{klass}\n|class #{klass} .*\n/)
      inject_into_file(path, *(args << config), &block)
    end

    # Run a regular expression replacement on a file.
    #
    # ==== Parameters
    # path<String>:: path of the file to be changed
    # flag<Regexp|String>:: the regexp or string to be replaced
    # replacement<String>:: the replacement, can be also given as a block
    # config<Hash>:: give :verbose => false to not log the status.
    #
    # ==== Example
    #
    #   gsub_file 'app/controllers/application_controller.rb', /#\s*(filter_parameter_logging :password)/, '\1'
    #
    #   gsub_file 'README', /rake/, :green do |match|
    #     match << " no more. Use thor!"
    #   end
    #
    def gsub_file(path, flag, *args, &block)
      return unless behavior == :invoke
      config = args.last.is_a?(Hash) ? args.pop : {}

      path = File.expand_path(path, destination_root)
      say_status :gsub, relative_to_original_destination_root(path), config.fetch(:verbose, true)

      unless options[:pretend]
        content = File.read(path)
        content.gsub!(flag, *args, &block)
        File.open(path, 'wb') { |file| file.write(content) }
      end
    end

    # Removes a file at the given location.
    #
    # ==== Parameters
    # path<String>:: path of the file to be changed
    # config<Hash>:: give :verbose => false to not log the status.
    #
    # ==== Example
    #
    #   remove_file 'README'
    #   remove_file 'app/controllers/application_controller.rb'
    #
    def remove_file(path, config={})
      return unless behavior == :invoke
      path  = File.expand_path(path, destination_root)

      say_status :remove, relative_to_original_destination_root(path), config.fetch(:verbose, true)
      ::FileUtils.rm_rf(path) if !options[:pretend] && File.exists?(path)
    end
    alias :remove_dir :remove_file

  end
end
