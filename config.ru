require './app'
use ActiveRecord::ConnectionAdapters::ConnectionManagement
run Sinatra::Application
configure do
    set :root
end