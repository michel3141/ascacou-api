class CreateGames < ActiveRecord::Migration[8.1]
  def change
    create_table :games do |t|
      t.references :room, null: false, foreign_key: true
      t.integer :number, null: false
      t.string :status, null: false
      t.integer :host_hand, array: true, null: false, default: []
      t.integer :guest_hand, array: true, null: false, default: []
      t.references :first_player, null: false, foreign_key: { to_table: :users }
      t.string :opening_color
      t.boolean :takeback_requested, null: false, default: false
      t.string :result
      t.string :end_reason
      t.integer :lock_version, null: false, default: 0

      t.timestamps
    end
    add_index :games, %i[room_id number], unique: true
  end
end
