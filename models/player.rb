configure :deveropment,:test do
    ActiveRecord::Base.establish_connection = YAML.load_file('config/database.yml')
end

configure :production do
    ActiveRecord::Base.establish_connection(ENV['DATABASE_URL'] || 'postgres://localhost/mydb'
end

class Player < ActiveRecord::Base 
    validates_presence_of :name
    validates_presence_of :scoreVR
    validates_presence_of :score2D
end