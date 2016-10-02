# coding: utf-8

class Menu < ActiveRecord::Base
  has_one :sub_menu, dependent: :destroy, autosave: true
  delegate :name, :name=, to: :sub_menu
end
