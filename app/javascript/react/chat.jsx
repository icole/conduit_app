import React, { useEffect, useState, useCallback } from 'react';
import { createRoot } from 'react-dom/client';
import {
  Chat,
  Channel,
  ChannelHeader,
  ChannelList,
  MessageInput,
  MessageList,
  Thread,
  Window,
  useCreateChatClient,
  useChatContext,
} from 'stream-chat-react';

import 'stream-chat-react/dist/css/v2/index.css';

// Modal for renaming a channel
const RenameChannelModal = ({ isOpen, onClose, channel, onChannelRenamed }) => {
  const [channelName, setChannelName] = useState(channel?.data?.name || '');
  const [isRenaming, setIsRenaming] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    if (channel?.data?.name) {
      setChannelName(channel.data.name);
    }
  }, [channel]);

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!channelName.trim() || !channel) return;

    setIsRenaming(true);
    setError('');

    try {
      const response = await fetch(`/chat/channels/${channel.id}`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content,
        },
        body: JSON.stringify({ name: channelName.trim() }),
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || 'Failed to rename channel');
      }

      onChannelRenamed();
      onClose();
    } catch (err) {
      console.error('Error renaming channel:', err);
      setError(err.message || 'Failed to rename channel');
    } finally {
      setIsRenaming(false);
    }
  };

  if (!isOpen) return null;

  return (
    <div className="modal modal-open">
      <div className="modal-box">
        <h3 className="font-bold text-lg">Rename channel</h3>
        <form onSubmit={handleSubmit} className="mt-4">
          <div className="form-control">
            <label className="label">
              <span className="label-text">Channel name</span>
            </label>
            <div className="flex items-center gap-2">
              <span className="text-base-content/60 text-lg">#</span>
              <input
                type="text"
                className="input input-bordered flex-1"
                value={channelName}
                onChange={(e) => setChannelName(e.target.value)}
                autoFocus
              />
            </div>
          </div>
          {error && (
            <div className="alert alert-error mt-4">
              <span>{error}</span>
            </div>
          )}
          <div className="modal-action">
            <button type="button" className="btn" onClick={onClose}>
              Cancel
            </button>
            <button
              type="submit"
              className="btn btn-primary"
              disabled={!channelName.trim() || isRenaming}
            >
              {isRenaming ? (
                <span className="loading loading-spinner loading-sm"></span>
              ) : (
                'Rename'
              )}
            </button>
          </div>
        </form>
      </div>
      <div className="modal-backdrop" onClick={onClose}></div>
    </div>
  );
};

// Modal for confirming channel deletion
const DeleteChannelModal = ({ isOpen, onClose, channel, onChannelDeleted }) => {
  const [isDeleting, setIsDeleting] = useState(false);
  const [error, setError] = useState('');

  const handleDelete = async () => {
    if (!channel) return;

    setIsDeleting(true);
    setError('');

    try {
      const response = await fetch(`/chat/channels/${channel.id}`, {
        method: 'DELETE',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content,
        },
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || 'Failed to delete channel');
      }

      onChannelDeleted();
      onClose();
    } catch (err) {
      console.error('Error deleting channel:', err);
      setError(err.message || 'Failed to delete channel');
    } finally {
      setIsDeleting(false);
    }
  };

  if (!isOpen) return null;

  return (
    <div className="modal modal-open">
      <div className="modal-box">
        <h3 className="font-bold text-lg text-error">Delete channel</h3>
        <p className="py-4">
          Are you sure you want to delete <strong>#{channel?.data?.name || channel?.id}</strong>?
          This action cannot be undone and all messages will be lost.
        </p>
        {error && (
          <div className="alert alert-error mt-4">
            <span>{error}</span>
          </div>
        )}
        <div className="modal-action">
          <button type="button" className="btn" onClick={onClose}>
            Cancel
          </button>
          <button
            type="button"
            className="btn btn-error"
            onClick={handleDelete}
            disabled={isDeleting}
          >
            {isDeleting ? (
              <span className="loading loading-spinner loading-sm"></span>
            ) : (
              'Delete Channel'
            )}
          </button>
        </div>
      </div>
      <div className="modal-backdrop" onClick={onClose}></div>
    </div>
  );
};

// Custom channel header with settings menu
const CustomChannelHeader = ({ channel, isAdmin, onRename, onDelete }) => {
  const [showMenu, setShowMenu] = useState(false);
  const { name } = channel?.data || {};

  return (
    <div className="chat-header-custom">
      <div className="flex items-center gap-2 flex-1">
        <span className="text-base-content/60 text-xl">#</span>
        <h2 className="font-bold text-lg">{name || channel?.id}</h2>
      </div>
      <div className="dropdown dropdown-end">
        <button
          tabIndex={0}
          className="btn btn-ghost btn-sm btn-circle"
          onClick={() => setShowMenu(!showMenu)}
        >
          <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 5v.01M12 12v.01M12 19v.01M12 6a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2z" />
          </svg>
        </button>
        <ul tabIndex={0} className="dropdown-content z-50 menu p-2 shadow-lg bg-base-100 rounded-box w-48">
          <li>
            <button onClick={() => { setShowMenu(false); onRename(); }}>
              <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" />
              </svg>
              Rename channel
            </button>
          </li>
          {isAdmin && (
            <li>
              <button onClick={() => { setShowMenu(false); onDelete(); }} className="text-error">
                <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                </svg>
                Delete channel
              </button>
            </li>
          )}
        </ul>
      </div>
    </div>
  );
};

// Modal for creating a new channel
const CreateChannelModal = ({ isOpen, onClose, onChannelCreated }) => {
  const { client } = useChatContext();
  const [channelName, setChannelName] = useState('');
  const [isCreating, setIsCreating] = useState(false);
  const [error, setError] = useState('');

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!channelName.trim()) return;

    setIsCreating(true);
    setError('');

    try {
      // Create channel via server endpoint (handles adding all community members)
      const response = await fetch('/chat/channels', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content,
        },
        body: JSON.stringify({ name: channelName.trim() }),
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || 'Failed to create channel');
      }

      // Now watch the channel on the client
      const channel = client.channel('team', data.channel_id);
      await channel.watch();

      onChannelCreated(channel);
      setChannelName('');
      onClose();
    } catch (err) {
      console.error('Error creating channel:', err);
      setError(err.message || 'Failed to create channel');
    } finally {
      setIsCreating(false);
    }
  };

  if (!isOpen) return null;

  return (
    <div className="modal modal-open">
      <div className="modal-box">
        <h3 className="font-bold text-lg">Create a new channel</h3>
        <form onSubmit={handleSubmit} className="mt-4">
          <div className="form-control">
            <label className="label">
              <span className="label-text">Channel name</span>
            </label>
            <div className="flex items-center gap-2">
              <span className="text-base-content/60 text-lg">#</span>
              <input
                type="text"
                placeholder="e.g. general, announcements"
                className="input input-bordered flex-1"
                value={channelName}
                onChange={(e) => setChannelName(e.target.value)}
                autoFocus
              />
            </div>
          </div>
          {error && (
            <div className="alert alert-error mt-4">
              <span>{error}</span>
            </div>
          )}
          <div className="modal-action">
            <button type="button" className="btn" onClick={onClose}>
              Cancel
            </button>
            <button
              type="submit"
              className="btn btn-primary"
              disabled={!channelName.trim() || isCreating}
            >
              {isCreating ? (
                <span className="loading loading-spinner loading-sm"></span>
              ) : (
                'Create Channel'
              )}
            </button>
          </div>
        </form>
      </div>
      <div className="modal-backdrop" onClick={onClose}></div>
    </div>
  );
};

// Slack-style channel preview
const CustomChannelPreview = ({ channel, setActiveChannel, activeChannel, unreadCount }) => {
  const isActive = activeChannel?.id === channel.id;
  const { name } = channel.data || {};
  const hasUnread = unreadCount > 0;

  return (
    <div
      onClick={() => setActiveChannel(channel)}
      className={`chat-channel-item ${isActive ? 'active' : ''}`}
    >
      <span className="hash">#</span>
      <span className={hasUnread ? 'font-bold' : ''}>{name || channel.id}</span>
      {hasUnread && (
        <span className="unread-badge">{unreadCount > 99 ? '99+' : unreadCount}</span>
      )}
    </div>
  );
};

// Main Chat App Component
const ChatApp = ({ apiKey, userToken, userData, isAdmin }) => {
  const [activeChannel, setActiveChannel] = useState(null);
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [showRenameModal, setShowRenameModal] = useState(false);
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [channelListKey, setChannelListKey] = useState(0);

  const client = useCreateChatClient({
    apiKey,
    tokenOrProvider: userToken,
    userData: {
      id: userData.id,
      name: userData.name,
      image: userData.avatar,
    },
  });

  const handleChannelCreated = useCallback((channel) => {
    setActiveChannel(channel);
    // Force channel list to refresh
    setChannelListKey((prev) => prev + 1);
  }, []);

  const handleChannelRenamed = useCallback(() => {
    // Force channel list to refresh
    setChannelListKey((prev) => prev + 1);
  }, []);

  const handleChannelDeleted = useCallback(() => {
    setActiveChannel(null);
    // Force channel list to refresh
    setChannelListKey((prev) => prev + 1);
  }, []);

  if (!client) {
    return (
      <div className="flex items-center justify-center h-full bg-base-100">
        <div className="loading loading-spinner loading-lg text-primary"></div>
      </div>
    );
  }

  const filters = { type: 'team', members: { $in: [userData.id] } };
  const sort = { last_message_at: -1 };

  return (
    <Chat client={client} theme="str-chat__theme-light">
      <div className="flex h-full">
        {/* Sidebar */}
        <div className="chat-sidebar w-64 flex flex-col">
          <div className="chat-channel-section flex-1 flex flex-col">
            <div className="chat-channel-section-header">Channels</div>
            <div className="flex-1 overflow-y-auto">
              <ChannelList
                key={channelListKey}
                filters={filters}
                sort={sort}
                Preview={(props) => (
                  <CustomChannelPreview
                    {...props}
                    activeChannel={activeChannel}
                    setActiveChannel={(channel) => {
                      setActiveChannel(channel);
                    }}
                    unreadCount={props.channel.state.unreadCount}
                  />
                )}
                setActiveChannel={setActiveChannel}
              />
            </div>
          </div>
          {/* New Channel Button */}
          <div className="chat-new-channel-btn" onClick={() => setShowCreateModal(true)}>
            <span className="chat-new-channel-icon">+</span>
            <span>New Channel</span>
          </div>
        </div>

        <CreateChannelModal
          isOpen={showCreateModal}
          onClose={() => setShowCreateModal(false)}
          onChannelCreated={handleChannelCreated}
        />

        <RenameChannelModal
          isOpen={showRenameModal}
          onClose={() => setShowRenameModal(false)}
          channel={activeChannel}
          onChannelRenamed={handleChannelRenamed}
        />

        <DeleteChannelModal
          isOpen={showDeleteModal}
          onClose={() => setShowDeleteModal(false)}
          channel={activeChannel}
          onChannelDeleted={handleChannelDeleted}
        />

        {/* Main Chat Area */}
        <div className="chat-main flex-1 flex flex-col min-w-0">
          {activeChannel ? (
            <Channel channel={activeChannel}>
              <Window>
                <CustomChannelHeader
                  channel={activeChannel}
                  isAdmin={isAdmin}
                  onRename={() => setShowRenameModal(true)}
                  onDelete={() => setShowDeleteModal(true)}
                />
                <MessageList />
                <MessageInput focus />
              </Window>
              <Thread />
            </Channel>
          ) : (
            <div className="chat-empty-state">
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
              </svg>
              <h3>Select a channel</h3>
              <p>Choose a channel from the sidebar to start chatting.</p>
            </div>
          )}
        </div>
      </div>
    </Chat>
  );
};

// Mount the React app
const mountChat = () => {
  const container = document.getElementById('stream-chat-react');
  if (!container) return;

  const apiKey = container.dataset.apiKey;
  const userToken = container.dataset.userToken;
  const userData = JSON.parse(container.dataset.userData);
  const isAdmin = container.dataset.isAdmin === 'true';

  const root = createRoot(container);
  root.render(
    <ChatApp
      apiKey={apiKey}
      userToken={userToken}
      userData={userData}
      isAdmin={isAdmin}
    />
  );
};

// Initialize when DOM is ready or on Turbo navigation
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', mountChat);
} else {
  mountChat();
}

// Re-initialize on Turbo navigation
document.addEventListener('turbo:load', mountChat);
