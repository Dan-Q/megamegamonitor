class AddAttachmentIconHigherToSubreddits < ActiveRecord::Migration
  def self.up
    change_table :subreddits do |t|
      t.attachment :icon_higher
    end
  end

  def self.down
    remove_attachment :subreddits, :icon_higher
  end
end
