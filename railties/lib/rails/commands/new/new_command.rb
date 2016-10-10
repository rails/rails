module Rails
  module Command
    class NewCommand < Base
      def help
        Rails::Command.invoke :application, [ "--help" ]
      end

      def perform(*)
        puts "Can't initialize a new Rails application within the directory of another, please change to a non-Rails directory first.\n"
        puts "Type 'rails' for help."
        exit 1
      end
    end
  end
end
