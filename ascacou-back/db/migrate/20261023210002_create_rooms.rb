class CreateRooms < ActiveRecord::Migration[8.1]
  def change
    create_table :rooms do |t|
      t.references :host, null: false, foreign_key: { to_table: :users }
      t.references :guest, foreign_key: { to_table: :users }
      t.string :code, null: false, index: { unique: true }
      t.string :visibility, null: false, default: "private"
      t.string :status, null: false, default: "waiting"
      t.string :deal_method, null: false, default: "random"
      t.boolean :allow_multiple, null: false, default: false
      t.boolean :imposed_color, null: false, default: false

      t.timestamps
    end
    add_index :rooms, %i[visibility status]
  end
end
