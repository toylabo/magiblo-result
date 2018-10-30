require './app'
use ActiveRecord::ConnectionAdapters::ConnectionManagement
run Sinatra::Application

set :root, './'