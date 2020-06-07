# frozen_string_literal: true

require "abstract_unit"
require "template/resolver_shared_tests"

class FileSystemResolverTest < ActiveSupport::TestCase
  include ResolverSharedTests

  def resolver
    ActionView::FileSystemResolver.new(tmpdir)
  end
end
