class AddAttachmentIconDefaultToSubreddits < ActiveRecord::Migration
  def self.up
    change_table :subreddits do |t|
      t.attachment :icon_default
    end
  end

  def self.down
    remove_attachment :subreddits, :icon_default
  end
end
