require 'cases/helper'
require 'models/developer'
require 'models/computer'
require 'models/advisor'
require 'models/post'
require 'models/comment'

module ActiveRecord
  module Associations
    class AssociationThroughWithProcTest < ActiveRecord::TestCase
      fixtures :posts


    end
  end
end
