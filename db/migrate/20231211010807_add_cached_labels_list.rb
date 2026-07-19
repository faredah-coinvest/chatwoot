class AddCachedLabelsList < ActiveRecord::Migration[7.0]
  def change
    add_column :conversations, :cached_label_list, :string
    Conversation.reset_column_information
    # acts-as-taggable-on renamed the cache module in v12
    if defined?(ActsAsTaggableOn::Taggable::Cache)
      ActsAsTaggableOn::Taggable::Cache.included(Conversation)
    elsif defined?(ActsAsTaggableOn::Taggable::Caching)
      ActsAsTaggableOn::Taggable::Caching.included(Conversation)
    end
  end
end
