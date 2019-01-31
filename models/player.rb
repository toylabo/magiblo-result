require 'sinatra'

configure :deveropment,:test do
    ActiveRecord::Base.establish_connection = YAML.load_file('config/database.yml')
end

configure :production do
    ActiveRecord::Base.establish_connection(ENV['DATABASE_URL'] || 'postgres://localhost/mydb')
end

class Player < ActiveRecord::Base 
    validates :name, presence: true
    validates :scoreVR, presence: true
    validates :score2D, presence: true
    validates :isWinVR, presence: true
    validates :isWin2D, presence: true
    validates :charaVR, presence: true
    validates :chara2D, presence: true
end