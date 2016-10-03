# coding: utf-8

class SubMenu < ActiveRecord::Base
  belongs_to :menu, touch: true
end
