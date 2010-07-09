module ActiveSupport
  # This class is responsible to track files and invoke the given block
  # whenever one of these files are changed. For example, this class
  # is used by Rails to reload the I18n framework whenever they are
  # changed upon a new request.
  #
  #   i18n_reloader = ActiveSupport::FileUpdateChecker.new(paths) do
  #     I18n.reload!
  #   end
  #
  #   ActionDispatch::Callbacks.to_prepare do
  #     i18n_reloader.execute_if_updated
  #   end
  #
  class FileUpdateChecker
    attr_reader :paths, :last_update_at

    def initialize(paths, calculate=false, &block)
      @paths = paths
      @block = block
      @last_update_at = calculate ? updated_at : nil
    end

    def updated_at
      paths.map { |path| File.stat(path).mtime }.max
    end

    def execute_if_updated
      current_update_at = self.updated_at
      if @last_update_at != current_update_at
        @last_update_at = current_update_at
        @block.call
      end
    end
  end
end
