# -*- encoding : utf-8 -*-
Rails.application.routes.draw do

  mount <%= camelized %>::Engine => "/<%= name %>"
end
