import React, { useCallback, useEffect, useState, useRef, forwardRef, useImperativeHandle, useMemo } from 'react';
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
  useMarkThreadAsResolved,
} from '@liveblocks/react/suspense';
import {
  useLiveblocksExtension,
  FloatingComposer,
  FloatingThreads,
  AnchoredThreads,
  Toolbar,
  FloatingToolbar,
} from '@liveblocks/react-tiptap';
import { Thread } from '@liveblocks/react-ui';
import '@liveblocks/react-ui/styles.css';
import '@liveblocks/react-tiptap/styles.css';

// Custom styles for the editor
const editorStyles = `
  .lb-root {
    --lb-accent: #2563eb;
  }

  /* Anchored threads sidebar styles */
  .threads-sidebar .lb-anchored-threads {
    padding-top: 1rem;
  }

  .threads-sidebar .lb-thread {
    margin-left: 0;
    margin-right: 0;
    max-width: 100%;
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

// Image upload button for the toolbar
const ImageButton = ({ editor, documentId }) => {
  const [isUploading, setIsUploading] = useState(false);
  const fileInputRef = useRef(null);

  const handleClick = (e) => {
    e.preventDefault();
    e.stopPropagation();
    fileInputRef.current?.click();
  };

  const handleFileChange = async (e) => {
    const file = e.target.files?.[0];
    if (!file) return;

    // Reset input so same file can be selected again
    e.target.value = '';

    // Validate it's an image
    if (!file.type.startsWith('image/')) {
      alert('Please select an image file');
      return;
    }

    setIsUploading(true);

    try {
      const formData = new FormData();
      formData.append('image', file);

      const response = await fetch(`/documents/${documentId}/upload_image`, {
        method: 'POST',
        body: formData,
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content || '',
        },
      });

      if (response.ok) {
        const { url } = await response.json();
        editor?.chain().focus().setImage({ src: url }).run();
      } else {
        const error = await response.json();
        alert(error.error || 'Failed to upload image');
      }
    } catch (error) {
      console.error('Error uploading image:', error);
      alert('Failed to upload image');
    } finally {
      setIsUploading(false);
    }
  };

  return (
    <>
      <input
        ref={fileInputRef}
        type="file"
        accept="image/*"
        onChange={handleFileChange}
        className="hidden"
      />
      <button
        type="button"
        onClick={handleClick}
        disabled={isUploading}
        className={`flex items-center gap-1 px-2 py-1 rounded hover:bg-gray-100 cursor-pointer ${isUploading ? 'opacity-50' : ''}`}
        title="Insert image"
      >
        {isUploading ? (
          <div className="w-4 h-4 border-2 border-gray-400 border-t-transparent rounded-full animate-spin" />
        ) : (
          <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
          </svg>
        )}
      </button>
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

// Threads wrapper - manages thread state and renders sidebar + floating threads
const ThreadsWrapper = ({ editor, showSidebar, onThreadCountChange }) => {
  const { threads } = useThreads();
  const markThreadAsResolved = useMarkThreadAsResolved();

  // Determine which threads have valid anchors in the document
  const { activeThreads, orphanedThreads } = useMemo(() => {
    if (!editor) return { activeThreads: [], orphanedThreads: [] };

    const active = [];
    const orphaned = [];

    threads.forEach(thread => {
      if (thread.resolved) return; // Skip already resolved
      if (thread.comments.length === 0) {
        orphaned.push(thread);
        return;
      }

      // Try to find the anchor mark in the document
      let hasAnchor = false;
      editor.state.doc.descendants((node) => {
        if (node.marks) {
          node.marks.forEach((mark) => {
            if (mark.type.name === 'liveblocksCommentMark' && mark.attrs.threadId === thread.id) {
              hasAnchor = true;
            }
          });
        }
      });

      if (hasAnchor) {
        active.push(thread);
      } else {
        orphaned.push(thread);
      }
    });

    return { activeThreads: active, orphanedThreads: orphaned };
  }, [threads, editor]);

  // Auto-resolve orphaned threads
  useEffect(() => {
    orphanedThreads.forEach(thread => {
      console.log('Resolving orphaned thread:', thread.id);
      markThreadAsResolved(thread.id);
    });
  }, [orphanedThreads, markThreadAsResolved]);

  // Notify parent of thread count changes
  useEffect(() => {
    onThreadCountChange(activeThreads.length);
  }, [activeThreads.length, onThreadCountChange]);

  return (
    <>
      {/* Desktop sidebar */}
      {showSidebar && (
        <div className="threads-sidebar hidden xl:block w-80 shrink-0 border-l border-gray-200 bg-gray-50 px-3 self-stretch">
          <AnchoredThreads editor={editor} threads={activeThreads} />
        </div>
      )}

      {/* Mobile floating threads */}
      <div className="xl:hidden">
        <FloatingThreads editor={editor} threads={activeThreads} />
      </div>
    </>
  );
};

// Comments toggle button with count badge - receives count from parent to stay in sync
// Hidden on smaller screens where the sidebar isn't shown
const CommentsToggleButton = ({ isActive, onClick, count }) => {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`hidden xl:flex items-center gap-1 px-2 py-1 text-sm rounded ${isActive ? 'bg-blue-100 text-blue-700' : 'hover:bg-gray-100'}`}
      title={isActive ? "Hide comments" : "Show comments"}
    >
      <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 8h10M7 12h4m1 8l-4-4H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-3l-4 4z" />
      </svg>
      {count > 0 && (
        <span className={`text-xs font-medium px-1.5 py-0.5 rounded-full ${isActive ? 'bg-blue-600 text-white' : 'bg-gray-200 text-gray-700'}`}>
          {count}
        </span>
      )}
    </button>
  );
};


// The main collaborative editor
const CollaborativeEditor = ({ documentId, initialContent, saveUrl, readOnly }) => {
  const room = useRoom();
  const status = useStatus();
  // Pass initialContent to useLiveblocksExtension - it only sets content when room is empty
  const liveblocks = useLiveblocksExtension({
    initialContent: initialContent || undefined,
  });
  const [saveStatus, setSaveStatus] = useState('saved');
  const [isLoading, setIsLoading] = useState(true);
  const [showComments, setShowComments] = useState(false);
  const [threadCount, setThreadCount] = useState(0);
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
    <div className="collaborative-editor relative flex flex-col flex-1">
      <style>{editorStyles}</style>

      {/* Loading overlay while Liveblocks syncs */}
      {isLoading && (
        <div className="absolute inset-0 bg-white z-50 flex items-center justify-center min-h-[200px]">
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
          <CommentsToggleButton isActive={showComments} onClick={() => setShowComments(!showComments)} count={threadCount} />
        </div>,
        presencePortal
      )}

      {/* Toolbar */}
      {!readOnly && (
        <div className="border-b border-gray-200 bg-white sticky top-0 z-40 rounded-t-lg">
          <Toolbar
            editor={editor}
            after={
              <>
                <ColorPicker editor={editor} />
                <HighlightPicker editor={editor} />
                <FontFamilyPicker editor={editor} />
                <ImageButton editor={editor} documentId={documentId} />
                <YouTubeButton editor={editor} />
              </>
            }
          />
        </div>
      )}

      {/* Editor Content with optional comments sidebar */}
      <div className="flex bg-white flex-1">
        <div className="flex-1 p-3 sm:p-6 min-w-0">
          <EditorContent editor={editor} />
        </div>

        {/* Threads sidebar + mobile floating threads */}
        <ClientSideSuspense fallback={null}>
          <ThreadsWrapper
            editor={editor}
            showSidebar={showComments}
            onThreadCountChange={setThreadCount}
          />
        </ClientSideSuspense>
      </div>

      {/* Floating toolbar for text selection */}
      {!readOnly && <FloatingToolbar editor={editor} />}

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

// Standalone editor extensions (shared between standalone and read-only)
const standaloneExtensions = [
  StarterKit.configure({
    heading: { levels: [1, 2, 3] },
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
  Highlight.configure({ multicolor: true }),
  TaskList,
  TaskItem.configure({ nested: true }),
  TextAlign.configure({ types: ['heading', 'paragraph'] }),
  Image.configure({ HTMLAttributes: { class: 'rounded-lg' } }),
  Table.configure({ resizable: true }),
  TableRow,
  TableHeader,
  TableCell,
  Typography,
  Subscript,
  Superscript,
  CharacterCount,
  FontFamily,
  Youtube.configure({ HTMLAttributes: { class: 'rounded-lg' } }),
  Mention.configure({
    HTMLAttributes: { class: 'mention' },
    suggestion: mentionSuggestion,
  }),
];

// Simple read-only viewer without Liveblocks
const ReadOnlyViewer = ({ initialContent }) => {
  const editor = useEditor({
    extensions: [
      ...standaloneExtensions,
      Placeholder.configure({
        placeholder: '',
      }),
    ],
    content: initialContent,
    editable: false,
    editorProps: {
      attributes: {
        class: 'prose prose-sm sm:prose lg:prose-lg max-w-none focus:outline-none',
      },
    },
  });

  if (!editor) {
    return (
      <div className="flex items-center justify-center h-full">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  return (
    <div className="collaborative-editor">
      <style>{editorStyles}</style>
      <EditorContent editor={editor} />
    </div>
  );
};

// Standalone editor for imported docs (no Liveblocks, saves to DB)
const StandaloneEditor = ({ initialContent, saveUrl, documentId }) => {
  const [saveStatus, setSaveStatus] = useState('saved');
  const saveTimeoutRef = useRef(null);
  const lastSavedContentRef = useRef(initialContent);

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

  const editor = useEditor({
    extensions: [
      ...standaloneExtensions,
      Placeholder.configure({
        placeholder: 'Start writing...',
      }),
    ],
    content: initialContent,
    editable: true,
    editorProps: {
      attributes: {
        class: 'prose prose-sm sm:prose lg:prose-lg max-w-none focus:outline-none',
        spellcheck: 'true',
      },
    },
    onUpdate: ({ editor }) => {
      setSaveStatus('saving');
      if (saveTimeoutRef.current) {
        clearTimeout(saveTimeoutRef.current);
      }
      saveTimeoutRef.current = setTimeout(() => {
        saveToServer(editor.getHTML());
      }, 1000);
    },
  });

  useEffect(() => {
    return () => {
      if (saveTimeoutRef.current) {
        clearTimeout(saveTimeoutRef.current);
      }
    };
  }, []);

  if (!editor) {
    return (
      <div className="flex items-center justify-center h-full">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  // Render save status into the presence portal if it exists
  const presencePortal = document.getElementById('presence-indicator-portal');

  return (
    <div className="collaborative-editor">
      <style>{editorStyles}</style>

      {presencePortal && createPortal(
        <div className="flex items-center gap-3">
          <span className={`text-xs ${
            saveStatus === 'saving' ? 'text-yellow-600' :
            saveStatus === 'error' ? 'text-red-600' :
            'text-green-600'
          }`}>
            {saveStatus === 'saving' ? 'Saving...' :
             saveStatus === 'error' ? 'Save failed' :
             'Saved'}
          </span>
        </div>,
        presencePortal
      )}

      {/* Toolbar */}
      <div className="border-b border-gray-200 bg-white px-2 py-1 flex flex-wrap items-center gap-1 sticky top-0 z-40 rounded-t-lg">
        {/* Text formatting */}
        <button
          type="button"
          onClick={() => editor.chain().focus().toggleBold().run()}
          className={`p-1.5 rounded hover:bg-gray-100 ${editor.isActive('bold') ? 'bg-gray-200' : ''}`}
          title="Bold (Ctrl+B)"
        >
          <span className="font-bold text-sm">B</span>
        </button>
        <button
          type="button"
          onClick={() => editor.chain().focus().toggleItalic().run()}
          className={`p-1.5 rounded hover:bg-gray-100 ${editor.isActive('italic') ? 'bg-gray-200' : ''}`}
          title="Italic (Ctrl+I)"
        >
          <span className="italic text-sm">I</span>
        </button>
        <button
          type="button"
          onClick={() => editor.chain().focus().toggleUnderline().run()}
          className={`p-1.5 rounded hover:bg-gray-100 ${editor.isActive('underline') ? 'bg-gray-200' : ''}`}
          title="Underline (Ctrl+U)"
        >
          <span className="underline text-sm">U</span>
        </button>
        <button
          type="button"
          onClick={() => editor.chain().focus().toggleStrike().run()}
          className={`p-1.5 rounded hover:bg-gray-100 ${editor.isActive('strike') ? 'bg-gray-200' : ''}`}
          title="Strikethrough"
        >
          <span className="line-through text-sm">S</span>
        </button>

        <div className="w-px h-6 bg-gray-300 mx-1" />

        {/* Headings */}
        <button
          type="button"
          onClick={() => editor.chain().focus().toggleHeading({ level: 1 }).run()}
          className={`p-1.5 rounded hover:bg-gray-100 ${editor.isActive('heading', { level: 1 }) ? 'bg-gray-200' : ''}`}
          title="Heading 1"
        >
          <span className="text-sm font-bold">H1</span>
        </button>
        <button
          type="button"
          onClick={() => editor.chain().focus().toggleHeading({ level: 2 }).run()}
          className={`p-1.5 rounded hover:bg-gray-100 ${editor.isActive('heading', { level: 2 }) ? 'bg-gray-200' : ''}`}
          title="Heading 2"
        >
          <span className="text-sm font-bold">H2</span>
        </button>
        <button
          type="button"
          onClick={() => editor.chain().focus().toggleHeading({ level: 3 }).run()}
          className={`p-1.5 rounded hover:bg-gray-100 ${editor.isActive('heading', { level: 3 }) ? 'bg-gray-200' : ''}`}
          title="Heading 3"
        >
          <span className="text-sm font-bold">H3</span>
        </button>

        <div className="w-px h-6 bg-gray-300 mx-1" />

        {/* Lists */}
        <button
          type="button"
          onClick={() => editor.chain().focus().toggleBulletList().run()}
          className={`p-1.5 rounded hover:bg-gray-100 ${editor.isActive('bulletList') ? 'bg-gray-200' : ''}`}
          title="Bullet List"
        >
          <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
          </svg>
        </button>
        <button
          type="button"
          onClick={() => editor.chain().focus().toggleOrderedList().run()}
          className={`p-1.5 rounded hover:bg-gray-100 ${editor.isActive('orderedList') ? 'bg-gray-200' : ''}`}
          title="Numbered List"
        >
          <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 20l4-16m2 16l4-16M6 9h14M4 15h14" />
          </svg>
        </button>
        <button
          type="button"
          onClick={() => editor.chain().focus().toggleTaskList().run()}
          className={`p-1.5 rounded hover:bg-gray-100 ${editor.isActive('taskList') ? 'bg-gray-200' : ''}`}
          title="Task List"
        >
          <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4" />
          </svg>
        </button>

        <div className="w-px h-6 bg-gray-300 mx-1" />

        {/* Block formatting */}
        <button
          type="button"
          onClick={() => editor.chain().focus().toggleBlockquote().run()}
          className={`p-1.5 rounded hover:bg-gray-100 ${editor.isActive('blockquote') ? 'bg-gray-200' : ''}`}
          title="Quote"
        >
          <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 10h.01M12 10h.01M16 10h.01M9 16H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-5l-5 5v-5z" />
          </svg>
        </button>
        <button
          type="button"
          onClick={() => editor.chain().focus().toggleCodeBlock().run()}
          className={`p-1.5 rounded hover:bg-gray-100 ${editor.isActive('codeBlock') ? 'bg-gray-200' : ''}`}
          title="Code Block"
        >
          <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4" />
          </svg>
        </button>

        <div className="w-px h-6 bg-gray-300 mx-1" />

        {/* Text alignment */}
        <button
          type="button"
          onClick={() => editor.chain().focus().setTextAlign('left').run()}
          className={`p-1.5 rounded hover:bg-gray-100 ${editor.isActive({ textAlign: 'left' }) ? 'bg-gray-200' : ''}`}
          title="Align Left"
        >
          <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h10M4 18h16" />
          </svg>
        </button>
        <button
          type="button"
          onClick={() => editor.chain().focus().setTextAlign('center').run()}
          className={`p-1.5 rounded hover:bg-gray-100 ${editor.isActive({ textAlign: 'center' }) ? 'bg-gray-200' : ''}`}
          title="Align Center"
        >
          <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M7 12h10M4 18h16" />
          </svg>
        </button>
        <button
          type="button"
          onClick={() => editor.chain().focus().setTextAlign('right').run()}
          className={`p-1.5 rounded hover:bg-gray-100 ${editor.isActive({ textAlign: 'right' }) ? 'bg-gray-200' : ''}`}
          title="Align Right"
        >
          <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M10 12h10M4 18h16" />
          </svg>
        </button>

        <div className="w-px h-6 bg-gray-300 mx-1" />

        {/* Colors and fonts */}
        <ColorPicker editor={editor} />
        <HighlightPicker editor={editor} />
        <FontFamilyPicker editor={editor} />

        <div className="w-px h-6 bg-gray-300 mx-1" />

        {/* Media */}
        <ImageButton editor={editor} documentId={documentId} />
        <YouTubeButton editor={editor} />
      </div>

      {/* Editor Content */}
      <div className="bg-white">
        <div className="p-3 sm:p-6">
          <EditorContent editor={editor} />
        </div>
      </div>

      {/* Link bubble menu */}
      <LinkBubbleMenu editor={editor} />
    </div>
  );
};

// Wrapper component with Liveblocks providers
const DocumentEditorApp = ({ documentId, initialContent, saveUrl, readOnly, imported }) => {
  // For read-only mode, use simple viewer without Liveblocks
  if (readOnly) {
    return <ReadOnlyViewer initialContent={initialContent} />;
  }

  // For imported docs (from Google Drive), use standalone editor without Liveblocks
  if (imported) {
    return <StandaloneEditor initialContent={initialContent} saveUrl={saveUrl} documentId={documentId} />;
  }

  // For native docs, use full collaborative editor with Liveblocks
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
  const encodedContent = container.dataset.initialContent || '';
  // Decode Base64 with proper UTF-8 handling
  const initialContent = encodedContent
    ? decodeURIComponent(atob(encodedContent).split('').map(c => '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2)).join(''))
    : '';
  const saveUrl = container.dataset.saveUrl;
  const readOnly = container.dataset.readOnly === 'true';
  const imported = container.dataset.imported === 'true';

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
      imported={imported}
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
