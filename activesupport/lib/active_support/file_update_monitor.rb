module ActiveSupport
  module FileUpdateMonitor
    autoload :Classic, 'active_support/file_update_monitor/classic'
    autoload :Evented, 'active_support/file_update_monitor/evented'

    # FileUpdateMonitor::Base specifies the API used by Rails to watch files
    # and control reloading. The API depends on four methods:
    #
    # * +initialize+ which expects two parameters and one block as
    #   described below.
    #
    # * +updated?+ which returns a boolean if there were updates in
    #   the filesystem or not.
    #
    # * +execute+ which executes the given block on initialization
    #   and updates the latest watched files and timestamp.
    #
    # * +execute_if_updated+ which just executes the block if it was updated.
    #
    # After initialization, a call to +execute_if_updated+ must execute
    # the block only if there was really a change in the filesystem.
    #
    # This class is used by Rails to reload the I18n framework whenever
    # they are changed upon a new request.
    #
    #   i18n_reloader = ActiveSupport::FileUpdateMonitor::Base.new(paths) do
    #     I18n.reload!
    #   end
    #
    #   ActiveSupport::Reloader.to_prepare do
    #     i18n_reloader.execute_if_updated
    #   end
    class Base
      # It accepts two parameters on initialization. The first is an array
      # of files and the second is an optional hash of directories. The hash must
      # have directories as keys and the value is an array of extensions to be
      # watched under that directory.
      #
      # This method must also receive a block that will be called once a path
      # changes. The array of files and list of directories cannot be changed
      # after the object has been initialized.
      def initialize(files, dirs = {}, &block)
        raise NotImplementedError
      end

      # Executes the given block
      def execute
        raise NotImplementedError
      end

      # Execute the block given if updated
      def execute_if_updated
        raise NotImplementedError
      end

      # Check if any of the entries were updated
      def updated?
        raise NotImplementedError
      end
    end
  end
end
