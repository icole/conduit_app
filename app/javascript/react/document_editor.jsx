import React, { useCallback, useEffect, useState, useRef } from 'react';
import { createRoot } from 'react-dom/client';
import { createPortal } from 'react-dom';
import { useEditor, EditorContent } from '@tiptap/react';
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
import TableRow from '@tiptap/extension-table-row';
import TableCell from '@tiptap/extension-table-cell';
import TableHeader from '@tiptap/extension-table-header';
import {
  LiveblocksProvider,
  RoomProvider,
  useRoom,
  useOthers,
  useSelf,
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
const CollaborativeEditor = ({ documentId, initialContent, onSave, readOnly }) => {
  const room = useRoom();
  const liveblocks = useLiveblocksExtension();

  const editor = useEditor({
    extensions: [
      liveblocks,
      StarterKit.configure({
        history: false, // Liveblocks handles history
        heading: {
          levels: [1, 2, 3],
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
    ],
    content: initialContent,
    editable: !readOnly,
    editorProps: {
      attributes: {
        class: 'prose prose-sm sm:prose lg:prose-lg max-w-none focus:outline-none',
      },
    },
  });

  // Save content when it changes (debounced via form submission)
  const handleSave = useCallback(() => {
    if (editor && onSave) {
      const html = editor.getHTML();
      onSave(html);
    }
  }, [editor, onSave]);

  // Expose save function to parent
  useEffect(() => {
    if (editor) {
      // Store save function on the container for Rails form integration
      const container = document.getElementById('document-editor-react');
      if (container) {
        container.saveContent = handleSave;
        container.getContent = () => editor.getHTML();
      }
    }
  }, [editor, handleSave]);

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
    <div className="collaborative-editor h-full flex flex-col">
      <style>{editorStyles}</style>

      {/* Presence indicator - rendered into header via portal */}
      {presencePortal && createPortal(<PresenceIndicator />, presencePortal)}

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
                  </>
                }
              />
            </div>
          )}

          {/* Editor Content - scrollable */}
          <div className="flex-1 overflow-auto bg-white">
            <div className="max-w-4xl mx-auto px-8 py-6">
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
const DocumentEditorApp = ({ documentId, initialContent, readOnly }) => {
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
          readOnly={readOnly}
        />
      </RoomProvider>
    </LiveblocksProvider>
  );
};

// Mount the React app
const mountDocumentEditor = () => {
  const container = document.getElementById('document-editor-react');
  if (!container) return;

  const documentId = container.dataset.documentId;
  const initialContent = container.dataset.initialContent || '';
  const readOnly = container.dataset.readOnly === 'true';

  const root = createRoot(container);
  root.render(
    <DocumentEditorApp
      documentId={documentId}
      initialContent={initialContent}
      readOnly={readOnly}
    />
  );
};

// Initialize when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', mountDocumentEditor);
} else {
  mountDocumentEditor();
}

// Also re-mount on Turbo navigation
document.addEventListener('turbo:load', mountDocumentEditor);

export default DocumentEditorApp;
