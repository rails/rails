
require 'abstract_unit'
require 'set'

require 'action_dispatch'
require 'active_support/time'

require 'mailers/base_mailer'
require 'mailers/proc_mailer'
require 'mailers/asset_mailer'

class CachingTest < ActiveSupport::TestCase
  include Rails::Dom::Testing::Assertions::DomAssertions
end
