class CreateRoomViewers < ActiveRecord::Migration[8.1]
  def change
    create_table :room_viewers do |t|
      t.references :room, null: false, foreign_key: true
      t.string :key, null: false, index: { unique: true }
      t.datetime :last_seen_at, null: false

      t.timestamps
    end
  end
end
