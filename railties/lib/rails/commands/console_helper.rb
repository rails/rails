require "active_support/concern"

module Rails
  module ConsoleHelper # :nodoc:
    extend ActiveSupport::Concern

    module ClassMethods
      def start(*args)
        new(*args).start
      end
      
      private
        def set_options_env(arguments, options)
          if arguments.first && arguments.first[0] != "-"
            env = arguments.first
            if available_environments.include? env
              options[:environment] = env
            else
              options[:environment] = %w(production development test).detect { |e| e =~ /^#{env}/ } || env
            end
          end
          options
        end

        def available_environments
          Dir["config/environments/*.rb"].map { |fname| File.basename(fname, ".*") }
        end  
    end

    def environment
      ENV["RAILS_ENV"] || ENV["RACK_ENV"] || "development"
    end
  end
end