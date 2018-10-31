class AddColumnsPlayerData < ActiveRecord::Migration[5.2]
  def change
    add_column :players, :isWinVR, :boolean
    add_column :players, :isWin2D, :boolean
    add_column :players, :charaVR, :string
    add_column :players, :chara2D, :string
    add_column :players, :restlessStr, :string
    add_column :players, :effortStr, :string
  end
end
