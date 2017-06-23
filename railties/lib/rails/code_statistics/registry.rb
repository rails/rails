class CodeStatistics::Registry
  Entity = Struct.new(:label, :dir, :tests?)

  attr_reader :entities

  # This method should not be called directly.
  # Access the registry via CodeStatistics.registry
  def initialize
    @entities = []
    @root = Rails.root
  end

  # Adds directory to the code statistics registry.
  # Note that it shouldn't be a subdirectory of a path
  # that is already tracked (app/models/concerns vs app/models)
  #
  # For example, if you want it to track code in config/nginx:
  #   CodeStatistics.registry.add("Nginx configs", "config/nginx")
  def add(label, dir)
    dir = @root.join(dir)
    return unless dir.directory?
    @entities << Entity.new(label, dir, false)
  end

  # Adds tests directory to the code statistics registry.
  # Example:
  #   CodeStatistics.registry.add("Feature tests", "test/features")
  def add_tests(label, dir)
    dir = @root.join(dir)
    return unless dir.directory?
    @entities << Entity.new(label, dir, true)
  end

  # Deletes directory from the code statistics registry.
  # Example:
  #   CodeStatistics.registry.delete("app/services")
  def delete(dir)
    dir = @root.join(dir)
    @entities.delete_if { |entity| entity.dir == dir }
  end
end
