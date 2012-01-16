require 'abstract_unit'

class LoadPathsTest < ActiveSupport::TestCase
  def test_uniq_load_paths
    load_paths_count = $LOAD_PATH.inject({}) { |paths, path|
      expanded_path = File.expand_path(path)
      paths[expanded_path] ||= 0
      paths[expanded_path] += 1
      paths
    }
    load_paths_count[File.expand_path('../../lib', __FILE__)] -= 1

    filtered = load_paths_count.select { |k, v| v > 1 }
    assert filtered.empty?, filtered.inspect
  end
end
