class AddAttachmentIconCurrentToSubreddits < ActiveRecord::Migration
  def self.up
    change_table :subreddits do |t|
      t.attachment :icon_current
    end
  end

  def self.down
    remove_attachment :subreddits, :icon_current
  end
end
