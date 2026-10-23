class CreateRoomPresences < ActiveRecord::Migration[8.1]
  def change
    create_table :room_presences do |t|
      t.references :room, null: false, foreign_key: true, index: false
      t.references :user, null: false, foreign_key: true
      t.datetime :last_seen_at, null: false

      t.timestamps
    end
    add_index :room_presences, %i[room_id user_id], unique: true
  end
end
