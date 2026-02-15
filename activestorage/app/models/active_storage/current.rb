# frozen_string_literal: true

# = Active Storage \Current
#
# Disk service for development and testing is a special case
# as it requires protocol, host and port specified additionally
# in order to generate url, which non-disk services can usually dispense with.
# 
# Use ActiveStorage::SetCurrent to effectively test the custom controllers' behavior
# to generate url no matter what type of service underlies the storage.
#
#   class UsersController < ApplicationController
#     include ActiveStorage::SetCurrent
#
#     def show
#       @user = User.find(params[:id])
#       @url = @user.profile.url
#     end
#   end
#
# If including the module like above does not help because, for example,
# controllers do not participate in generating url, use Current.url_options= but with caution.
# Knowing the nature of ActiveSupport::CurrentAttributes would be of help.
class ActiveStorage::Current < ActiveSupport::CurrentAttributes
  ##
  # :singleton-method: url_options
  #
  # Returns the options for the current request.

  ##
  # :singleton-method: url_options=
  # :call-seq: url_options=(options)
  #
  # Sets the options for the current request.
  # For the supported options, see ActionDispatch::Routing::UrlFor#url_for.

  attribute :url_options
end
