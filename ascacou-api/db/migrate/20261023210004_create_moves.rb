class CreateMoves < ActiveRecord::Migration[8.1]
  def change
    create_table :moves do |t|
      t.references :game, null: false, foreign_key: true, index: false
      t.integer :rank, null: false
      t.string :coord, null: false
      t.string :color, null: false
      t.string :next_color

      t.timestamps
    end
    add_index :moves, %i[game_id rank], unique: true
    add_index :moves, %i[game_id coord], unique: true
  end
end
