class AddColumnTotal < ActiveRecord::Migration[5.2]
  def change
    add_column :players, :total, :integer
  end
end
