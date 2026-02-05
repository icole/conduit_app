import React, { useCallback, useEffect, useState, useRef, forwardRef, useImperativeHandle } from 'react';
import { createRoot } from 'react-dom/client';
import { createPortal } from 'react-dom';
import { useEditor, EditorContent, BubbleMenu, ReactRenderer } from '@tiptap/react';
import StarterKit from '@tiptap/starter-kit';
import Placeholder from '@tiptap/extension-placeholder';
import Link from '@tiptap/extension-link';
import Underline from '@tiptap/extension-underline';
import TextStyle from '@tiptap/extension-text-style';
import Color from '@tiptap/extension-color';
import Highlight from '@tiptap/extension-highlight';
import TaskList from '@tiptap/extension-task-list';
import TaskItem from '@tiptap/extension-task-item';
import TextAlign from '@tiptap/extension-text-align';
import Image from '@tiptap/extension-image';
import Table from '@tiptap/extension-table';
import Typography from '@tiptap/extension-typography';
import TableRow from '@tiptap/extension-table-row';
import TableCell from '@tiptap/extension-table-cell';
import TableHeader from '@tiptap/extension-table-header';
import Subscript from '@tiptap/extension-subscript';
import Superscript from '@tiptap/extension-superscript';

import CharacterCount from '@tiptap/extension-character-count';
import FontFamily from '@tiptap/extension-font-family';
import Youtube from '@tiptap/extension-youtube';
import Mention from '@tiptap/extension-mention';
import tippy from 'tippy.js';
import {
  LiveblocksProvider,
  RoomProvider,
  useRoom,
  useOthers,
  useSelf,
  useStatus,
} from '@liveblocks/react';
import {
  ClientSideSuspense,
  useThreads,
} from '@liveblocks/react/suspense';
import {
  useLiveblocksExtension,
  FloatingComposer,
  FloatingThreads,
  AnchoredThreads,
  Toolbar,
  FloatingToolbar,
} from '@liveblocks/react-tiptap';
import '@liveblocks/react-ui/styles.css';
import '@liveblocks/react-tiptap/styles.css';

// Custom styles for the editor
const editorStyles = `
  .lb-root {
    --lb-accent: #2563eb;
  }

  .collaborative-editor .ProseMirror {
    min-height: 400px;
    padding: 1rem;
    outline: none;
  }

  .collaborative-editor .ProseMirror p.is-editor-empty:first-child::before {
    color: #adb5bd;
    content: attr(data-placeholder);
    float: left;
    height: 0;
    pointer-events: none;
  }

  .collaborative-editor .ProseMirror ul[data-type="taskList"] {
    list-style: none;
    padding: 0;
  }

  .collaborative-editor .ProseMirror ul[data-type="taskList"] li {
    display: flex;
    align-items: flex-start;
    gap: 0.5rem;
  }

  .collaborative-editor .ProseMirror ul[data-type="taskList"] li > label {
    flex: 0 0 auto;
    margin-top: 0.25rem;
  }

  .collaborative-editor .ProseMirror table {
    border-collapse: collapse;
    margin: 1rem 0;
    width: 100%;
  }

  .collaborative-editor .ProseMirror th,
  .collaborative-editor .ProseMirror td {
    border: 1px solid #d1d5db;
    padding: 0.5rem;
    text-align: left;
  }

  .collaborative-editor .ProseMirror th {
    background-color: #f3f4f6;
    font-weight: 600;
  }

  .collaborative-editor .ProseMirror img {
    max-width: 100%;
    height: auto;
  }

  .collaborative-editor .ProseMirror blockquote {
    border-left: 3px solid #d1d5db;
    margin: 1rem 0;
    padding-left: 1rem;
    color: #6b7280;
  }

  .collaborative-editor .ProseMirror pre {
    background-color: #1f2937;
    color: #f3f4f6;
    padding: 1rem;
    border-radius: 0.375rem;
    overflow-x: auto;
  }

  .collaborative-editor .ProseMirror code {
    background-color: #f3f4f6;
    padding: 0.125rem 0.25rem;
    border-radius: 0.25rem;
    font-size: 0.875rem;
  }

  .collaborative-editor .ProseMirror pre code {
    background: none;
    padding: 0;
  }

  .collaborative-editor .ProseMirror mark {
    background-color: #fef08a;
    padding: 0.125rem 0;
  }

  .collaborative-editor .ProseMirror h1 {
    font-size: 2rem;
    font-weight: 700;
    margin-top: 1.5rem;
    margin-bottom: 0.75rem;
    line-height: 1.2;
  }

  .collaborative-editor .ProseMirror h2 {
    font-size: 1.5rem;
    font-weight: 600;
    margin-top: 1.25rem;
    margin-bottom: 0.5rem;
    line-height: 1.3;
  }

  .collaborative-editor .ProseMirror h3 {
    font-size: 1.25rem;
    font-weight: 600;
    margin-top: 1rem;
    margin-bottom: 0.5rem;
    line-height: 1.4;
  }

  /* Mention pill styling */
  .collaborative-editor .ProseMirror .mention {
    background-color: #dbeafe;
    color: #1d4ed8;
    border-radius: 9999px;
    padding: 0.125rem 0.375rem;
    font-weight: 500;
    font-size: 0.875em;
    white-space: nowrap;
  }

  /* YouTube embed responsive wrapper */
  .collaborative-editor .ProseMirror div[data-youtube-video] {
    position: relative;
    width: 100%;
    padding-bottom: 56.25%;
    height: 0;
    margin: 1rem 0;
  }

  .collaborative-editor .ProseMirror div[data-youtube-video] iframe {
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    border-radius: 0.375rem;
  }

  /* Ensure editor fills available space */
  .collaborative-editor .ProseMirror {
    min-height: 100%;
  }
`;

// Color picker component for the toolbar
const ColorPicker = ({ editor }) => {
  const [isOpen, setIsOpen] = useState(false);
  const [position, setPosition] = useState({ top: 0, left: 0 });
  const buttonRef = useRef(null);
  const dropdownRef = useRef(null);

  const colors = [
    '#000000', '#374151', '#6b7280',
    '#dc2626', '#ea580c', '#d97706',
    '#ca8a04', '#65a30d', '#16a34a',
    '#059669', '#0d9488', '#0891b2',
    '#0284c7', '#2563eb', '#4f46e5',
    '#7c3aed', '#9333ea', '#c026d3',
    '#db2777', '#e11d48',
  ];

  const currentColor = editor?.getAttributes('textStyle').color || '#000000';

  // Close on outside click
  useEffect(() => {
    const handleClickOutside = (e) => {
      if (
        buttonRef.current && !buttonRef.current.contains(e.target) &&
        dropdownRef.current && !dropdownRef.current.contains(e.target)
      ) {
        setIsOpen(false);
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  const applyColor = (color) => {
    editor?.chain().focus().setColor(color).run();
    setIsOpen(false);
  };

  const removeColor = () => {
    editor?.chain().focus().unsetColor().run();
    setIsOpen(false);
  };

  const handleToggle = (e) => {
    e.preventDefault();
    e.stopPropagation();
    if (!isOpen && buttonRef.current) {
      const rect = buttonRef.current.getBoundingClientRect();
      setPosition({ top: rect.bottom + 4, left: rect.left });
    }
    setIsOpen(!isOpen);
  };

  return (
    <>
      <button
        ref={buttonRef}
        type="button"
        onClick={handleToggle}
        className="flex items-center gap-1 px-2 py-1 rounded hover:bg-gray-100 cursor-pointer"
        title="Text color"
      >
        <span className="text-sm font-medium">A</span>
        <span
          className="w-4 h-1 rounded-sm"
          style={{ backgroundColor: currentColor }}
        />
      </button>
      {isOpen && createPortal(
        <div
          ref={dropdownRef}
          className="fixed p-2 bg-white border border-gray-200 rounded-lg shadow-lg grid grid-cols-6 gap-1 z-[9999] min-w-[160px]"
          style={{ top: position.top, left: position.left }}
        >
          {colors.map((color) => (
            <button
              key={color}
              type="button"
              onClick={() => applyColor(color)}
              className="w-6 h-6 rounded border border-gray-200 hover:scale-110 transition-transform cursor-pointer"
              style={{ backgroundColor: color }}
              title={color}
            />
          ))}
          <button
            type="button"
            onClick={removeColor}
            className="col-span-6 mt-1 px-2 py-1 text-xs text-gray-600 hover:bg-gray-100 rounded cursor-pointer"
          >
            Remove color
          </button>
        </div>,
        document.body
      )}
    </>
  );
};

// Highlight color picker component
const HighlightPicker = ({ editor }) => {
  const [isOpen, setIsOpen] = useState(false);
  const [position, setPosition] = useState({ top: 0, left: 0 });
  const buttonRef = useRef(null);
  const dropdownRef = useRef(null);

  const colors = [
    '#fef08a', '#fde047', '#facc15',
    '#bef264', '#86efac', '#6ee7b7',
    '#67e8f9', '#7dd3fc', '#93c5fd',
    '#c4b5fd', '#d8b4fe', '#f0abfc',
    '#fda4af', '#fecaca', '#fed7aa',
  ];

  // Close on outside click
  useEffect(() => {
    const handleClickOutside = (e) => {
      if (
        buttonRef.current && !buttonRef.current.contains(e.target) &&
        dropdownRef.current && !dropdownRef.current.contains(e.target)
      ) {
        setIsOpen(false);
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  const applyHighlight = (color) => {
    editor?.chain().focus().toggleHighlight({ color }).run();
    setIsOpen(false);
  };

  const removeHighlight = () => {
    editor?.chain().focus().unsetHighlight().run();
    setIsOpen(false);
  };

  const handleToggle = (e) => {
    e.preventDefault();
    e.stopPropagation();
    if (!isOpen && buttonRef.current) {
      const rect = buttonRef.current.getBoundingClientRect();
      setPosition({ top: rect.bottom + 4, left: rect.left });
    }
    setIsOpen(!isOpen);
  };

  return (
    <>
      <button
        ref={buttonRef}
        type="button"
        onClick={handleToggle}
        className="flex items-center gap-1 px-2 py-1 rounded hover:bg-gray-100 cursor-pointer"
        title="Highlight"
      >
        <span className="text-sm px-1 bg-yellow-200 rounded">H</span>
      </button>
      {isOpen && createPortal(
        <div
          ref={dropdownRef}
          className="fixed p-2 bg-white border border-gray-200 rounded-lg shadow-lg grid grid-cols-5 gap-1 z-[9999] min-w-[140px]"
          style={{ top: position.top, left: position.left }}
        >
          {colors.map((color) => (
            <button
              key={color}
              type="button"
              onClick={() => applyHighlight(color)}
              className="w-6 h-6 rounded border border-gray-200 hover:scale-110 transition-transform cursor-pointer"
              style={{ backgroundColor: color }}
              title={color}
            />
          ))}
          <button
            type="button"
            onClick={removeHighlight}
            className="col-span-5 mt-1 px-2 py-1 text-xs text-gray-600 hover:bg-gray-100 rounded cursor-pointer"
          >
            Remove highlight
          </button>
        </div>,
        document.body
      )}
    </>
  );
};

// Font family picker for the toolbar
const FontFamilyPicker = ({ editor }) => {
  const [isOpen, setIsOpen] = useState(false);
  const [position, setPosition] = useState({ top: 0, left: 0 });
  const buttonRef = useRef(null);
  const dropdownRef = useRef(null);

  const fonts = [
    { label: 'Default', value: '' },
    { label: 'Inter', value: 'Inter' },
    { label: 'Merriweather', value: 'Merriweather' },
    { label: 'Fira Code', value: 'Fira Code' },
    { label: 'Lora', value: 'Lora' },
    { label: 'Open Sans', value: 'Open Sans' },
    { label: 'Roboto Mono', value: 'Roboto Mono' },
  ];

  const currentFont = editor?.getAttributes('textStyle').fontFamily || '';

  useEffect(() => {
    const handleClickOutside = (e) => {
      if (
        buttonRef.current && !buttonRef.current.contains(e.target) &&
        dropdownRef.current && !dropdownRef.current.contains(e.target)
      ) {
        setIsOpen(false);
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  const applyFont = (fontFamily) => {
    if (fontFamily) {
      editor?.chain().focus().setFontFamily(fontFamily).run();
    } else {
      editor?.chain().focus().unsetFontFamily().run();
    }
    setIsOpen(false);
  };

  const handleToggle = (e) => {
    e.preventDefault();
    e.stopPropagation();
    if (!isOpen && buttonRef.current) {
      const rect = buttonRef.current.getBoundingClientRect();
      setPosition({ top: rect.bottom + 4, left: rect.left });
    }
    setIsOpen(!isOpen);
  };

  const displayLabel = fonts.find(f => f.value === currentFont)?.label || 'Font';

  return (
    <>
      <button
        ref={buttonRef}
        type="button"
        onClick={handleToggle}
        className="flex items-center gap-1 px-2 py-1 rounded hover:bg-gray-100 cursor-pointer text-sm"
        title="Font family"
      >
        <span className="truncate max-w-[80px]">{displayLabel}</span>
        <svg className="w-3 h-3 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
        </svg>
      </button>
      {isOpen && createPortal(
        <div
          ref={dropdownRef}
          className="fixed bg-white border border-gray-200 rounded-lg shadow-lg z-[9999] py-1 min-w-[160px]"
          style={{ top: position.top, left: position.left }}
        >
          {fonts.map((font) => (
            <button
              key={font.value}
              type="button"
              onClick={() => applyFont(font.value)}
              className={`w-full text-left px-3 py-1.5 text-sm hover:bg-gray-100 cursor-pointer ${
                currentFont === font.value ? 'bg-blue-50 text-blue-600' : ''
              }`}
              style={font.value ? { fontFamily: font.value } : {}}
            >
              {font.label}
            </button>
          ))}
        </div>,
        document.body
      )}
    </>
  );
};

// YouTube embed button for the toolbar
const YouTubeButton = ({ editor }) => {
  const [isOpen, setIsOpen] = useState(false);
  const [url, setUrl] = useState('');
  const [position, setPosition] = useState({ top: 0, left: 0 });
  const buttonRef = useRef(null);
  const popoverRef = useRef(null);
  const inputRef = useRef(null);

  useEffect(() => {
    const handleClickOutside = (e) => {
      if (
        buttonRef.current && !buttonRef.current.contains(e.target) &&
        popoverRef.current && !popoverRef.current.contains(e.target)
      ) {
        setIsOpen(false);
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  useEffect(() => {
    if (isOpen && inputRef.current) {
      inputRef.current.focus();
    }
  }, [isOpen]);

  const handleToggle = (e) => {
    e.preventDefault();
    e.stopPropagation();
    if (!isOpen && buttonRef.current) {
      const rect = buttonRef.current.getBoundingClientRect();
      setPosition({ top: rect.bottom + 4, left: rect.left });
    }
    setUrl('');
    setIsOpen(!isOpen);
  };

  const embedVideo = () => {
    if (url.trim()) {
      editor?.commands.setYoutubeVideo({ src: url.trim() });
    }
    setUrl('');
    setIsOpen(false);
  };

  const handleKeyDown = (e) => {
    if (e.key === 'Enter') {
      e.preventDefault();
      embedVideo();
    } else if (e.key === 'Escape') {
      setIsOpen(false);
    }
  };

  return (
    <>
      <button
        ref={buttonRef}
        type="button"
        onClick={handleToggle}
        className="flex items-center gap-1 px-2 py-1 rounded hover:bg-gray-100 cursor-pointer"
        title="Embed YouTube video"
      >
        <svg className="w-4 h-4" viewBox="0 0 24 24" fill="currentColor">
          <path d="M23.498 6.186a3.016 3.016 0 0 0-2.122-2.136C19.505 3.545 12 3.545 12 3.545s-7.505 0-9.377.505A3.017 3.017 0 0 0 .502 6.186C0 8.07 0 12 0 12s0 3.93.502 5.814a3.016 3.016 0 0 0 2.122 2.136c1.871.505 9.376.505 9.376.505s7.505 0 9.377-.505a3.015 3.015 0 0 0 2.122-2.136C24 15.93 24 12 24 12s0-3.93-.502-5.814zM9.545 15.568V8.432L15.818 12l-6.273 3.568z"/>
        </svg>
      </button>
      {isOpen && createPortal(
        <div
          ref={popoverRef}
          className="fixed bg-white border border-gray-200 rounded-lg shadow-lg z-[9999] p-3"
          style={{ top: position.top, left: position.left }}
        >
          <div className="flex items-center gap-2">
            <input
              ref={inputRef}
              type="url"
              value={url}
              onChange={(e) => setUrl(e.target.value)}
              onKeyDown={handleKeyDown}
              className="border border-gray-300 rounded px-2 py-1 text-sm w-64 outline-none focus:border-blue-500"
              placeholder="Paste YouTube URL..."
            />
            <button
              type="button"
              onClick={embedVideo}
              className="px-3 py-1 bg-blue-600 text-white text-sm rounded hover:bg-blue-700 cursor-pointer"
            >
              Embed
            </button>
          </div>
        </div>,
        document.body
      )}
    </>
  );
};

// Mention suggestion list component
const MentionList = forwardRef(({ items, command }, ref) => {
  const [selectedIndex, setSelectedIndex] = useState(0);

  useEffect(() => {
    setSelectedIndex(0);
  }, [items]);

  useImperativeHandle(ref, () => ({
    onKeyDown: ({ event }) => {
      if (event.key === 'ArrowUp') {
        setSelectedIndex((prev) => (prev + items.length - 1) % items.length);
        return true;
      }
      if (event.key === 'ArrowDown') {
        setSelectedIndex((prev) => (prev + 1) % items.length);
        return true;
      }
      if (event.key === 'Enter') {
        const item = items[selectedIndex];
        if (item) command({ id: item.id, label: item.name });
        return true;
      }
      return false;
    },
  }));

  if (!items.length) {
    return (
      <div className="bg-white border border-gray-200 rounded-lg shadow-lg p-2 text-sm text-gray-500">
        No results
      </div>
    );
  }

  return (
    <div className="bg-white border border-gray-200 rounded-lg shadow-lg py-1 min-w-[180px]">
      {items.map((item, index) => (
        <button
          key={item.id}
          type="button"
          className={`w-full text-left px-3 py-1.5 text-sm cursor-pointer flex items-center gap-2 ${
            index === selectedIndex ? 'bg-blue-50 text-blue-700' : 'hover:bg-gray-50'
          }`}
          onClick={() => command({ id: item.id, label: item.name })}
        >
          {item.avatar_url ? (
            <img src={item.avatar_url} className="w-5 h-5 rounded-full" alt="" />
          ) : (
            <span className="w-5 h-5 rounded-full bg-gray-300 flex items-center justify-center text-xs text-white">
              {item.name?.charAt(0) || '?'}
            </span>
          )}
          <span>{item.name}</span>
        </button>
      ))}
    </div>
  );
});

// Mention suggestion configuration
const mentionSuggestion = {
  items: async ({ query }) => {
    if (!query) return [];
    try {
      const response = await fetch(`/api/v1/users/search?q=${encodeURIComponent(query)}`);
      if (!response.ok) return [];
      return await response.json();
    } catch {
      return [];
    }
  },
  render: () => {
    let component;
    let popup;

    return {
      onStart: (props) => {
        component = new ReactRenderer(MentionList, {
          props,
          editor: props.editor,
        });

        if (!props.clientRect) return;

        popup = tippy('body', {
          getReferenceClientRect: props.clientRect,
          appendTo: () => document.body,
          content: component.element,
          showOnCreate: true,
          interactive: true,
          trigger: 'manual',
          placement: 'bottom-start',
        });
      },
      onUpdate: (props) => {
        component?.updateProps(props);
        if (props.clientRect && popup?.[0]) {
          popup[0].setProps({ getReferenceClientRect: props.clientRect });
        }
      },
      onKeyDown: (props) => {
        if (props.event.key === 'Escape') {
          popup?.[0]?.hide();
          return true;
        }
        return component?.ref?.onKeyDown(props);
      },
      onExit: () => {
        popup?.[0]?.destroy();
        component?.destroy();
      },
    };
  },
};

// Link bubble menu shown when cursor is on a link
const LinkBubbleMenu = ({ editor }) => {
  const [isEditing, setIsEditing] = useState(false);
  const [linkUrl, setLinkUrl] = useState('');
  const inputRef = useRef(null);

  const currentUrl = editor?.getAttributes('link').href || '';

  useEffect(() => {
    if (isEditing && inputRef.current) {
      inputRef.current.focus();
      inputRef.current.select();
    }
  }, [isEditing]);

  const openLink = () => {
    if (currentUrl) {
      window.open(currentUrl, '_blank', 'noopener,noreferrer');
    }
  };

  const startEditing = () => {
    setLinkUrl(currentUrl);
    setIsEditing(true);
  };

  const saveLink = () => {
    if (linkUrl.trim()) {
      editor?.chain().focus().extendMarkRange('link').setLink({ href: linkUrl.trim() }).run();
    }
    setIsEditing(false);
  };

  const removeLink = () => {
    editor?.chain().focus().extendMarkRange('link').unsetLink().run();
    setIsEditing(false);
  };

  const handleKeyDown = (e) => {
    if (e.key === 'Enter') {
      e.preventDefault();
      saveLink();
    } else if (e.key === 'Escape') {
      setIsEditing(false);
    }
  };

  return (
    <BubbleMenu
      editor={editor}
      tippyOptions={{ placement: 'bottom-start', maxWidth: '400px' }}
      shouldShow={({ editor }) => editor.isActive('link')}
    >
      <div className="flex items-center gap-1 bg-white border border-gray-200 rounded-lg shadow-lg px-2 py-1.5 text-sm">
        {isEditing ? (
          <>
            <input
              ref={inputRef}
              type="url"
              value={linkUrl}
              onChange={(e) => setLinkUrl(e.target.value)}
              onKeyDown={handleKeyDown}
              className="border border-gray-300 rounded px-2 py-0.5 text-sm w-56 outline-none focus:border-blue-500"
              placeholder="https://..."
            />
            <button
              type="button"
              onClick={saveLink}
              className="px-2 py-0.5 text-blue-600 hover:bg-blue-50 rounded cursor-pointer text-sm"
            >
              Save
            </button>
            <button
              type="button"
              onClick={() => setIsEditing(false)}
              className="px-2 py-0.5 text-gray-500 hover:bg-gray-100 rounded cursor-pointer text-sm"
            >
              Cancel
            </button>
          </>
        ) : (
          <>
            <a
              href={currentUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="text-blue-600 underline truncate max-w-[200px] hover:text-blue-800"
              onClick={(e) => {
                e.preventDefault();
                openLink();
              }}
            >
              {currentUrl}
            </a>
            <button
              type="button"
              onClick={openLink}
              className="p-1 text-gray-500 hover:bg-gray-100 rounded cursor-pointer"
              title="Open link"
            >
              <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
              </svg>
            </button>
            <button
              type="button"
              onClick={startEditing}
              className="p-1 text-gray-500 hover:bg-gray-100 rounded cursor-pointer"
              title="Edit link"
            >
              <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" />
              </svg>
            </button>
            <button
              type="button"
              onClick={removeLink}
              className="p-1 text-gray-500 hover:bg-gray-100 rounded cursor-pointer"
              title="Remove link"
            >
              <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1" />
              </svg>
            </button>
          </>
        )}
      </div>
    </BubbleMenu>
  );
};

// Presence indicator showing who's online
const PresenceIndicator = () => {
  const others = useOthers();
  const self = useSelf();

  if (!self) return null;

  return (
    <div className="flex items-center gap-2">
      <div className="flex -space-x-1">
        {/* Self */}
        <div
          className="w-6 h-6 rounded-full border-2 border-gray-50 flex items-center justify-center text-white text-xs font-medium"
          style={{ backgroundColor: self.info?.color || '#888' }}
          title={`${self.info?.name || 'You'} (you)`}
        >
          {self.info?.name?.charAt(0) || '?'}
        </div>
        {/* Others */}
        {others.map((other) => (
          <div
            key={other.connectionId}
            className="w-6 h-6 rounded-full border-2 border-gray-50 flex items-center justify-center text-white text-xs font-medium"
            style={{ backgroundColor: other.info?.color || '#888' }}
            title={other.info?.name || 'Anonymous'}
          >
            {other.info?.name?.charAt(0) || '?'}
          </div>
        ))}
      </div>
      <span className="text-xs text-gray-500">
        {others.length > 0
          ? `${others.length + 1} people editing`
          : 'Only you'}
      </span>
    </div>
  );
};

// Threads component - must be wrapped in ClientSideSuspense
const Threads = ({ editor }) => {
  const { threads } = useThreads({ query: { resolved: false } });

  if (threads.length === 0) {
    return (
      <p className="text-sm text-gray-500 italic">
        No comments yet. Select text and click the comment button to add one.
      </p>
    );
  }

  return (
    <>
      <AnchoredThreads editor={editor} threads={threads} />
      <FloatingThreads editor={editor} threads={threads} className="xl:hidden" />
    </>
  );
};

// The main collaborative editor
const CollaborativeEditor = ({ documentId, initialContent, saveUrl, readOnly }) => {
  const room = useRoom();
  const status = useStatus();
  const liveblocks = useLiveblocksExtension();
  const [saveStatus, setSaveStatus] = useState('saved');
  const [isLoading, setIsLoading] = useState(true);
  const saveTimeoutRef = useRef(null);
  const lastSavedContentRef = useRef(initialContent);

  const editor = useEditor({
    extensions: [
      liveblocks,
      StarterKit.configure({
        history: false, // Liveblocks handles history
        heading: {
          levels: [1, 2, 3],
        },
        dropcursor: {
          color: '#2563eb',
          width: 2,
        },
      }),
      Placeholder.configure({
        placeholder: 'Start writing your document...',
      }),
      Link.configure({
        openOnClick: false,
        HTMLAttributes: {
          class: 'text-blue-600 underline hover:text-blue-800',
        },
      }),
      Underline,
      TextStyle,
      Color,
      Highlight.configure({
        multicolor: true,
      }),
      TaskList,
      TaskItem.configure({
        nested: true,
      }),
      TextAlign.configure({
        types: ['heading', 'paragraph'],
      }),
      Image.configure({
        HTMLAttributes: {
          class: 'rounded-lg',
        },
      }),
      Table.configure({
        resizable: true,
      }),
      TableRow,
      TableHeader,
      TableCell,
      Typography,
      Subscript,
      Superscript,
CharacterCount,
      FontFamily,
      Youtube.configure({
        HTMLAttributes: {
          class: 'rounded-lg',
        },
      }),
      Mention.configure({
        HTMLAttributes: {
          class: 'mention',
        },
        suggestion: mentionSuggestion,
      }),
    ],
    content: initialContent,
    editable: !readOnly,
    editorProps: {
      attributes: {
        class: 'prose prose-sm sm:prose lg:prose-lg max-w-none focus:outline-none',
        spellcheck: 'true',
      },
    },
    onUpdate: ({ editor }) => {
      // Debounced auto-save on content change
      if (!readOnly && saveUrl) {
        setSaveStatus('saving');

        // Clear existing timeout
        if (saveTimeoutRef.current) {
          clearTimeout(saveTimeoutRef.current);
        }

        // Set new timeout for debounced save
        saveTimeoutRef.current = setTimeout(() => {
          saveToServer(editor.getHTML());
        }, 1000); // Save 1 second after user stops typing
      }
    },
  });

  // Save content to Rails server
  const saveToServer = useCallback(async (content) => {
    if (!saveUrl || content === lastSavedContentRef.current) {
      setSaveStatus('saved');
      return;
    }

    try {
      const response = await fetch(saveUrl, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: JSON.stringify({ content }),
      });

      if (response.ok) {
        lastSavedContentRef.current = content;
        setSaveStatus('saved');
      } else {
        console.error('Failed to save document:', response.status);
        setSaveStatus('error');
      }
    } catch (error) {
      console.error('Error saving document:', error);
      setSaveStatus('error');
    }
  }, [saveUrl]);

  // Cleanup timeout on unmount
  useEffect(() => {
    return () => {
      if (saveTimeoutRef.current) {
        clearTimeout(saveTimeoutRef.current);
      }
    };
  }, []);

  // Wait for Liveblocks to sync before showing editor content
  useEffect(() => {
    if (status === 'connected' && editor) {
      // Give Liveblocks a moment to sync the document content
      const syncTimeout = setTimeout(() => {
        setIsLoading(false);
      }, 300);
      return () => clearTimeout(syncTimeout);
    }
  }, [status, editor]);

  // Expose save function to parent
  useEffect(() => {
    if (editor) {
      // Store save function on the container for Rails form integration
      const container = document.getElementById('document-editor-react');
      if (container) {
        container.saveContent = () => saveToServer(editor.getHTML());
        container.getContent = () => editor.getHTML();
      }
    }
  }, [editor, saveToServer]);

  if (!room || !editor) {
    return (
      <div className="flex items-center justify-center h-full">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  // Get the portal container for presence indicator
  const presencePortal = document.getElementById('presence-indicator-portal');

  return (
    <div className="collaborative-editor h-full flex flex-col relative">
      <style>{editorStyles}</style>

      {/* Loading overlay while Liveblocks syncs */}
      {isLoading && (
        <div className="absolute inset-0 bg-white z-50 flex items-center justify-center">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
        </div>
      )}

      {/* Presence indicator and save status - rendered into header via portal */}
      {presencePortal && createPortal(
        <div className="flex items-center gap-3">
          <PresenceIndicator />
          {!readOnly && (
            <span className={`text-xs ${
              saveStatus === 'saving' ? 'text-yellow-600' :
              saveStatus === 'error' ? 'text-red-600' :
              'text-green-600'
            }`}>
              {saveStatus === 'saving' ? 'Saving...' :
               saveStatus === 'error' ? 'Save failed' :
               'Saved'}
            </span>
          )}
          <span className="text-xs text-gray-400">
            {editor.storage.characterCount.words()} words
          </span>
        </div>,
        presencePortal
      )}

      {/* Main content area with editor and optional sidebar */}
      <div className="flex-1 flex overflow-hidden">
        {/* Editor panel */}
        <div className="flex-1 flex flex-col min-w-0">
          {/* Toolbar */}
          {!readOnly && (
            <div className="border-b border-gray-200 bg-white">
              <Toolbar
                editor={editor}
                after={
                  <>
                    <ColorPicker editor={editor} />
                    <HighlightPicker editor={editor} />
                    <FontFamilyPicker editor={editor} />
                    <YouTubeButton editor={editor} />
                  </>
                }
              />
            </div>
          )}

          {/* Editor Content - scrollable */}
          <div className="flex-1 overflow-auto bg-white">
            <div className="px-4 py-4">
              <EditorContent editor={editor} />
            </div>
          </div>

          {/* Floating toolbar for text selection */}
          {!readOnly && <FloatingToolbar editor={editor} />}
        </div>

        {/* Comments sidebar - visible on large screens */}
        <ClientSideSuspense fallback={null}>
          <div className="hidden xl:block w-80 border-l border-gray-200 bg-gray-50 overflow-auto">
            <div className="p-4">
              <h3 className="text-sm font-medium text-gray-700 mb-3">Comments</h3>
              <Threads editor={editor} />
            </div>
          </div>
        </ClientSideSuspense>
      </div>

      {/* Liveblocks floating UI */}
      <FloatingComposer editor={editor} style={{ width: '350px' }} />

      {/* Link bubble menu */}
      <LinkBubbleMenu editor={editor} />
    </div>
  );
};

// Resolve user IDs to user info for comments
async function resolveUsers({ userIds }) {
  const params = new URLSearchParams();
  userIds.forEach(id => params.append('userIds[]', id));

  const response = await fetch(`/api/liveblocks/users?${params.toString()}`);
  if (!response.ok) {
    return userIds.map(() => ({ name: 'Unknown User' }));
  }

  return response.json();
}

// Wrapper component with Liveblocks providers
const DocumentEditorApp = ({ documentId, initialContent, saveUrl, readOnly }) => {
  const roomId = `document:${documentId}`;

  return (
    <LiveblocksProvider
      authEndpoint="/api/liveblocks/auth"
      resolveUsers={resolveUsers}
    >
      <RoomProvider
        id={roomId}
        initialPresence={{}}
      >
        <CollaborativeEditor
          documentId={documentId}
          initialContent={initialContent}
          saveUrl={saveUrl}
          readOnly={readOnly}
        />
      </RoomProvider>
    </LiveblocksProvider>
  );
};

// Store the root reference to prevent duplicate mounts
let documentEditorRoot = null;

// Mount the React app
const mountDocumentEditor = () => {
  const container = document.getElementById('document-editor-react');
  if (!container) return;

  // Skip if already mounted on this container
  if (container.dataset.mounted === 'true') return;

  const documentId = container.dataset.documentId;
  const initialContent = container.dataset.initialContent || '';
  const saveUrl = container.dataset.saveUrl;
  const readOnly = container.dataset.readOnly === 'true';

  // Unmount previous root if exists
  if (documentEditorRoot) {
    documentEditorRoot.unmount();
    documentEditorRoot = null;
  }

  container.dataset.mounted = 'true';
  documentEditorRoot = createRoot(container);
  documentEditorRoot.render(
    <DocumentEditorApp
      documentId={documentId}
      initialContent={initialContent}
      saveUrl={saveUrl}
      readOnly={readOnly}
    />
  );
};

// Unmount on Turbo navigation away
const unmountDocumentEditor = () => {
  const container = document.getElementById('document-editor-react');
  if (container) {
    container.dataset.mounted = 'false';
  }

  // Clear the presence portal to prevent cached content from showing
  const presencePortal = document.getElementById('presence-indicator-portal');
  if (presencePortal) {
    presencePortal.innerHTML = '';
  }

  if (documentEditorRoot) {
    documentEditorRoot.unmount();
    documentEditorRoot = null;
  }
};

// Initialize when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', mountDocumentEditor);
} else {
  mountDocumentEditor();
}

// Handle Turbo navigation
document.addEventListener('turbo:load', mountDocumentEditor);
document.addEventListener('turbo:before-render', unmountDocumentEditor);

export default DocumentEditorApp;
