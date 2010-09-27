require 'rubygems'
require 'spec'
require 'fileutils'
require 'arel'

require 'support/matchers/be_like'
require 'support/check'
require 'support/fake_record'
require 'support/shared/tree_manager_shared'

Spec::Runner.configure do |config|
  config.include Matchers
  config.include Check

  config.before do
    Arel::Table.engine = Arel::Sql::Engine.new(FakeRecord::Base.new)
  end
end
