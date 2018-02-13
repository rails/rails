# frozen_string_literal: true

class Admin::User < ActiveRecord::Base
  class Coder
    def initialize(default = {})
      @default = default
    end

    def dump(o)
      ActiveSupport::JSON.encode(o || @default)
    end

    def load(s)
      s.present? ? ActiveSupport::JSON.decode(s) : @default.clone
    end
  end

  belongs_to :account
  store :params, accessors: [ :token ], coder: YAML
  store :settings, accessors: [ :color, :homepage ]
  store_accessor :settings, :favorite_food
  store :preferences, accessors: [ :remember_login ]
  store :json_data, accessors: [ :height, :weight ], coder: Coder.new
  store :json_data_empty, accessors: [ :is_a_good_guy ], coder: Coder.new

  def phone_number
    read_store_attribute(:settings, :phone_number).gsub(/(\d{3})(\d{3})(\d{4})/, '(\1) \2-\3')
  end

  def phone_number=(value)
    write_store_attribute(:settings, :phone_number, value && value.gsub(/[^\d]/, ""))
  end

  def color
    super || "red"
  end

  def color=(value)
    value = "blue" unless %w(black red green blue).include?(value)
    super
  end
end
