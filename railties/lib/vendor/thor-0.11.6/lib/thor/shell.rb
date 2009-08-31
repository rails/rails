require 'thor/shell/color'

class Thor
  module Base
    # Returns the shell used in all Thor classes. Default to color one.
    #
    def self.shell
      @shell ||= Thor::Shell::Color
    end

    # Sets the shell used in all Thor classes.
    #
    def self.shell=(klass)
      @shell = klass
    end
  end

  module Shell
    SHELL_DELEGATED_METHODS = [:ask, :yes?, :no?, :say, :say_status, :print_list, :print_table]

    # Add shell to initialize config values.
    #
    # ==== Configuration
    # shell<Object>:: An instance of the shell to be used.
    #
    # ==== Examples
    #
    #   class MyScript < Thor
    #     argument :first, :type => :numeric
    #   end
    #
    #   MyScript.new [1.0], { :foo => :bar }, :shell => Thor::Shell::Basic.new
    #
    def initialize(args=[], options={}, config={})
      super
      self.shell = config[:shell]
      self.shell.base ||= self if self.shell.respond_to?(:base)
    end

    # Holds the shell for the given Thor instance. If no shell is given,
    # it gets a default shell from Thor::Base.shell.
    #
    def shell
      @shell ||= Thor::Base.shell.new
    end

    # Sets the shell for this thor class.
    #
    def shell=(shell)
      @shell = shell
    end

    # Common methods that are delegated to the shell.
    #
    SHELL_DELEGATED_METHODS.each do |method|
      module_eval <<-METHOD, __FILE__, __LINE__
        def #{method}(*args)
          shell.#{method}(*args)
        end
      METHOD
    end

    protected

      # Allow shell to be shared between invocations.
      #
      def _shared_configuration #:nodoc:
        super.merge!(:shell => self.shell)
      end

  end
end
