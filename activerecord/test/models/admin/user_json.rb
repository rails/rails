# frozen_string_literal: true

class Admin::UserJSON < ActiveRecord::Base
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
  store :params, accessors: [ :token ], coder: JSON
  store :settings, accessors: [ :color, :homepage ], coder: Coder.new
  store_accessor :settings, :favorite_food
  store :parent, accessors: [:birthday, :name], prefix: true, coder: Coder.new
  store :spouse, accessors: [:birthday], prefix: :partner, coder: Coder.new
  store_accessor :spouse, :name, prefix: :partner
  store :configs, accessors: [ :secret_question ], coder: Coder.new
  store :configs, accessors: [ :two_factor_auth ], suffix: true, coder: Coder.new
  store_accessor :configs, :login_retry, suffix: :config
  store :preferences, accessors: [ :remember_login ], coder: Coder.new
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
