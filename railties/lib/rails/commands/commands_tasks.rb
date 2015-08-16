require 'rails/commands/assets'
require 'rails/commands/cache_digests'
require 'rails/commands/command'
require 'rails/commands/core'
require 'rails/commands/db'
require 'rails/commands/docs'
require 'rails/commands/dev_cache'
require 'rails/commands/help'
require 'rails/commands/notes'
require 'rails/commands/test'
require 'rails/commands/tmp'

module Rails
  # This is a class which takes in a rails command and initiates the appropriate
  # initiation sequence.
  #
  # Warning: This class mutates ARGV because some commands require manipulating
  # it before they are run.
  class CommandsTasks # :nodoc:
    attr_reader :argv

    def initialize(argv)
      @argv = argv
      @command = Rails::Commands::Command.new(argv)
    end

    def run_command!(command)
      @command.run(command)
    rescue
      @command.run('help')
    end
  end
end
