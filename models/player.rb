ActiveRecord::Base.establish_connection(
        adapter: 'sqlite3',
        database: 'model.db'
    )
class Player < ActiveRecord::Base 
end