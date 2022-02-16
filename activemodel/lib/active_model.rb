# frozen_string_literal: true

#--
# Copyright (c) 2004-2022 David Heinemeier Hansson
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#++

require "active_support"
require "active_support/rails"
require "active_model/version"

module ActiveModel
  extend ActiveSupport::Autoload

  autoload :API
  autoload :Attribute
  autoload :Attributes
  autoload :AttributeAssignment
  autoload :AttributeMethods
  autoload :BlockValidator, "active_model/validator"
  autoload :Callbacks
  autoload :Conversion
  autoload :Dirty
  autoload :EachValidator, "active_model/validator"
  autoload :ForbiddenAttributesProtection
  autoload :Lint
  autoload :Model
  autoload :Name, "active_model/naming"
  autoload :Naming
  autoload :SecurePassword
  autoload :Serialization
  autoload :Translation
  autoload :Type
  autoload :Validations
  autoload :Validator

  eager_autoload do
    autoload :Errors
    autoload :Error
    autoload :RangeError, "active_model/errors"
    autoload :StrictValidationFailed, "active_model/errors"
    autoload :UnknownAttributeError, "active_model/errors"
  end

  module Serializers
    extend ActiveSupport::Autoload

    eager_autoload do
      autoload :JSON
    end
  end

  def self.eager_load!
    super
    ActiveModel::Serializers.eager_load!
  end
end

ActiveSupport.on_load(:i18n) do
  I18n.load_path << File.expand_path("active_model/locale/en.yml", __dir__)
end
