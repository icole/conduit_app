import React, { useEffect, useState } from 'react';
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
} from 'stream-chat-react';

import 'stream-chat-react/dist/css/v2/index.css';

// Custom channel preview to match our styling
const CustomChannelPreview = ({ channel, setActiveChannel, activeChannel }) => {
  const isActive = activeChannel?.id === channel.id;
  const { name } = channel.data || {};

  return (
    <div
      onClick={() => setActiveChannel(channel)}
      className={`p-3 rounded-lg cursor-pointer transition-colors ${
        isActive ? 'bg-primary/10 text-primary' : 'hover:bg-base-200'
      }`}
    >
      <div className="flex items-center gap-2">
        <span className="text-base-content/60">#</span>
        <span className="font-medium">{name || channel.id}</span>
      </div>
    </div>
  );
};

// Main Chat App Component
const ChatApp = ({ apiKey, userToken, userData }) => {
  const [activeChannel, setActiveChannel] = useState(null);

  const client = useCreateChatClient({
    apiKey,
    tokenOrProvider: userToken,
    userData: {
      id: userData.id,
      name: userData.name,
      image: userData.avatar,
    },
  });

  if (!client) {
    return (
      <div className="flex items-center justify-center h-full">
        <div className="loading loading-spinner loading-lg"></div>
      </div>
    );
  }

  const filters = { type: 'team', members: { $in: [userData.id] } };
  const sort = { last_message_at: -1 };

  return (
    <Chat client={client} theme="str-chat__theme-light">
      <div className="flex h-full">
        {/* Channel List Sidebar */}
        <div className="w-64 border-r border-base-300 flex flex-col">
          <div className="p-4 border-b border-base-300">
            <h2 className="font-semibold text-lg">Channels</h2>
          </div>
          <div className="flex-1 overflow-y-auto p-2">
            <ChannelList
              filters={filters}
              sort={sort}
              Preview={(props) => (
                <CustomChannelPreview
                  {...props}
                  activeChannel={activeChannel}
                  setActiveChannel={(channel) => {
                    setActiveChannel(channel);
                  }}
                />
              )}
              setActiveChannel={setActiveChannel}
            />
          </div>
        </div>

        {/* Main Chat Area */}
        <div className="flex-1 flex flex-col min-w-0">
          {activeChannel ? (
            <Channel channel={activeChannel}>
              <Window>
                <ChannelHeader />
                <MessageList />
                <MessageInput focus />
              </Window>
              <Thread />
            </Channel>
          ) : (
            <div className="flex items-center justify-center h-full text-base-content/50">
              <div className="text-center">
                <svg xmlns="http://www.w3.org/2000/svg" className="h-12 w-12 mx-auto mb-3 opacity-50" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
                </svg>
                <p className="font-medium">Select a channel</p>
                <p className="text-sm mt-1">Choose a channel from the sidebar to start chatting</p>
              </div>
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

  const root = createRoot(container);
  root.render(
    <ChatApp
      apiKey={apiKey}
      userToken={userToken}
      userData={userData}
    />
  );
};

// Initialize when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', mountChat);
} else {
  mountChat();
}
