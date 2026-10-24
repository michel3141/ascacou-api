class CreatePicks < ActiveRecord::Migration[8.1]
  def change
    create_table :picks do |t|
      t.references :game, null: false, foreign_key: true, index: false
      t.integer :rank, null: false
      t.integer :card, null: false
      t.string :hand, null: false

      t.timestamps
    end
    add_index :picks, %i[game_id rank], unique: true
    add_index :picks, %i[game_id card], unique: true
  end
end
