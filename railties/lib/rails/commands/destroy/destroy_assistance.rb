
module DestroyAssistance
    def self.delete_css_file_generate_with_scaffold
        path = Rails.root.join('app', 'assets', 'stylesheets', 'scaffolds.scss')
        FileUtils.remove_file(path,force=true)
        puts " "*6+"\e[31mremove\e[0m"+" "*4  + path.to_s.split("/").reverse.slice(0,4).reverse.join("/")
      end
end