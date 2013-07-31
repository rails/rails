Rails.application.routes.draw do

  mount <%= camelized %>::Engine => "/<%= name %>"
end
