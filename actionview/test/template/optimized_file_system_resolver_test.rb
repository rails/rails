# frozen_string_literal: true

require 'abstract_unit'
require 'template/resolver_shared_tests'

class OptimizedFileSystemResolverTest < ActiveSupport::TestCase
  include ResolverSharedTests

  def resolver
    ActionView::OptimizedFileSystemResolver.new(tmpdir)
  end
end
