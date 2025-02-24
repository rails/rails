# Be sure to restart your server when you modify this file.
#
# This file eases your Rails 8.1 framework defaults upgrade.
#
# Uncomment each configuration one by one to switch to the new default.
# Once your application is ready to run with all new defaults, you can remove
# this file and set the `config.load_defaults` to `8.1`.
#
# Read the Guide for Upgrading Ruby on Rails for more info on each option.
# https://guides.rubyonrails.org/upgrading_ruby_on_rails.html

###
# Skips escaping HTML entities and line separators. When set to `false`, the
# JSON renderer no longer escapes these to improve performance.
#
# Example:
#   class PostsController < ApplicationController
#     def index
#       render json: { key: "\u2028\u2029<>&" }
#     end
#   end
#
# Renders `{"key":"\u2028\u2029\u003c\u003e\u0026"}` with the previous default, but `{"key":"  <>&"}` with the config
# set to `false`.
#
# Applications that want to keep the escaping behavior can set the config to `true`.
#++
# Rails.configuration.action_controller.escape_json_responses = false

###
# Raises an error when order dependent finder methods (e.g. `#first`, `#second`) are called without `order` values
# on the relation, and the model does not have any order columns (`implicit_order_column`, `query_constraints`, or
# `primary_key`) to fall back on.
#
# The current behavior of not raising an error has been deprecated, and this configuration option will be removed in
# Rails 8.2.
#++
# Rails.configuration.active_record.raise_on_missing_required_finder_order_columns = true
