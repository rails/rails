module DependenciesTestHelpers
  def with_loading(*from)
    old_mechanism = ENV.delete('NO_RELOAD')
    this_dir = File.dirname(__FILE__)
    parent_dir = File.dirname(this_dir)
    path_copy = $LOAD_PATH.dup
    $LOAD_PATH.unshift(parent_dir) unless $LOAD_PATH.include?(parent_dir)
    prior_autoload_paths = ActiveSupport::Dependencies.autoload_paths
    ActiveSupport::Dependencies.autoload_paths = from.map { |f| File.join(this_dir, f) }
    yield
  ensure
    $LOAD_PATH.replace(path_copy) if path_copy
    ActiveSupport::Dependencies.autoload_paths = prior_autoload_paths
    ENV['NO_RELOAD'] = old_mechanism
  end

  def with_autoloading_fixtures(&block)
    with_loading 'autoloading_fixtures', &block
  end

  def remove_constants(*constants)
    constants.each do |constant|
      Object.send(:remove_const, constant) if Object.const_defined?(constant)
    end
  end
end