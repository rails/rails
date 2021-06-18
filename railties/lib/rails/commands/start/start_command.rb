module Rails
  module Command
    class StartCommand < Base # :nodoc:
      def initialize(args, local_options, *)
        super

        Rails::Command::ServerCommand.new(args, local_options)
      end
    end
  end
end
