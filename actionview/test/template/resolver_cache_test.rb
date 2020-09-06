# frozen_string_literal: true

require 'abstract_unit'

class ResolverCacheTest < ActiveSupport::TestCase
  def test_inspect_shields_cache_internals
    ActionView::LookupContext::DetailsKey.clear
    assert_match %r(#<ActionView::Resolver:0x[0-9a-f]+ @cache=#<ActionView::Resolver::Cache:0x[0-9a-f]+ keys=0 queries=0>>), ActionView::Resolver.new.inspect
  end
end
