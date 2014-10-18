require 'abstract_unit'

class LoadPathsTest < ActiveSupport::TestCase
  def test_uniq_load_paths
    load_paths_count = $LOAD_PATH.each_with_object({}) do |path, paths|
      expanded_path = File.expand_path(path)
      paths[expanded_path] ||= 0
      paths[expanded_path] += 1
    end
    load_paths_count[File.expand_path('../../lib', __FILE__)] -= 1

    load_paths_count.select! { |k, v| v > 1 }
    assert load_paths_count.empty?, load_paths_count.inspect
  end
end
