ActiveRecord::Base.establish_connection(
        adapter: 'sqlite3',
        database: 'model.db'
    )
class Player < ActiveRecord::Base 
    validates_presence_of :name
    validates_presence_of :scoreVR
    validates_presence_of :score2D
end