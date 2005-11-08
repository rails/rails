
desc "Update your javascripts from your current rails install."
task :update_javascripts do 
  require 'railties_path'  
  FileUtils.cp(Dir[RAILTIES_PATH + '/html/javascripts/*.js'], RAILS_ROOT + '/public/javascripts/')
end
