class BackfillCommunityFeatureFlags < ActiveRecord::Migration[8.1]
  # Flags default to off for new (self-created) communities. Every community
  # that exists today was set up by us and already uses chat and docs.
  def up
    execute <<~SQL
      UPDATE communities
      SET settings = COALESCE(settings, '{}'::jsonb) || '{"chat_enabled": true, "collaborative_docs_enabled": true}'::jsonb
    SQL
  end

  def down
    execute "UPDATE communities SET settings = settings - 'chat_enabled' - 'collaborative_docs_enabled'"
  end
end
