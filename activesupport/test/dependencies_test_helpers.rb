# frozen_string_literal: true

module DependenciesTestHelpers
  def with_loading(*from)
    old_mechanism, ActiveSupport::Dependencies.mechanism = ActiveSupport::Dependencies.mechanism, :load
    this_dir = __dir__
    parent_dir = File.dirname(this_dir)
    path_copy = $LOAD_PATH.dup
    $LOAD_PATH.unshift(parent_dir) unless $LOAD_PATH.include?(parent_dir)
    prior_autoload_paths = ActiveSupport::Dependencies.autoload_paths
    ActiveSupport::Dependencies.autoload_paths = from.collect { |f| "#{this_dir}/#{f}" }
    yield
  ensure
    $LOAD_PATH.replace(path_copy)
    ActiveSupport::Dependencies.autoload_paths = prior_autoload_paths
    ActiveSupport::Dependencies.mechanism = old_mechanism
    ActiveSupport::Dependencies.explicitly_unloadable_constants = []
    ActiveSupport::Dependencies.clear
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
