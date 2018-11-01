class PlayersChangeColomunToString < ActiveRecord::Migration[5.2]
  def change
    change_column :players, :isWinVR, :string
    change_column :players, :isWin2D, :string
  end
end
