class AddEncodedIconsToSubreddits < ActiveRecord::Migration
  def change
    add_column :subreddits, :encoded_icon_default, :string, limit: 4.kilobytes
    add_column :subreddits, :encoded_icon_current, :string, limit: 4.kilobytes
    add_column :subreddits, :encoded_icon_higher, :string, limit: 4.kilobytes
  end
end
