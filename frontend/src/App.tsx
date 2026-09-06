import { useEffect, useState } from "react";
import {
  call,
  encodeEmpty,
  encodeNat,
  encodeNatTextText,
  encodeTextText,
  query,
} from "./thebes";
import { useTheme } from "./useTheme";

type Note = { id: number; title: string; body: string };

export default function App() {
  const theme = useTheme();

  const [notes, setNotes] = useState<Note[]>([]);
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [editingId, setEditingId] = useState<number | null>(null);
  const [editTitle, setEditTitle] = useState("");
  const [editBody, setEditBody] = useState("");

  async function refreshNotes() {
    try {
      const raw = await query("list", encodeEmpty());
      setNotes(JSON.parse(String(raw)) as Note[]);
      setError(null);
    } catch (e) {
      setError(String(e));
    }
  }

  useEffect(() => {
    void refreshNotes();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function onAdd(e: React.FormEvent) {
    e.preventDefault();
    if (!title.trim()) return;
    setError(null);
    setBusy(true);
    try {
      await call("add", encodeTextText(title, body));
      setTitle("");
      setBody("");
      await refreshNotes();
    } catch (e) {
      setError(String(e));
    } finally {
      setBusy(false);
    }
  }

  function startEdit(note: Note) {
    setEditingId(note.id);
    setEditTitle(note.title);
    setEditBody(note.body);
  }

  async function onSaveEdit(id: number) {
    setError(null);
    setBusy(true);
    try {
      await call("edit", encodeNatTextText(id, editTitle, editBody));
      setEditingId(null);
      await refreshNotes();
    } catch (e) {
      setError(String(e));
    } finally {
      setBusy(false);
    }
  }

  async function onDelete(id: number) {
    setError(null);
    setBusy(true);
    try {
      await call("remove", encodeNat(id));
      await refreshNotes();
    } catch (e) {
      setError(String(e));
    } finally {
      setBusy(false);
    }
  }

  return (
    <main className="shell">
      <header>
        <button
          className="theme-toggle"
          onClick={theme.toggle}
          aria-label={`Switch to ${theme.effective === "dark" ? "light" : "dark"} mode`}
          title={`Switch to ${theme.effective === "dark" ? "light" : "dark"} mode`}
        >
          {theme.effective === "dark" ? "☀" : "☾"}
        </button>
        <div className="cartouche">𓊹</div>
        <h1>notes-app</h1>
        <p className="strap">a canister dapp, live on the Thebes substrate</p>
      </header>

      <section className="panel">
        <h2>Add a note — update, ordered by consensus</h2>
        <form onSubmit={onAdd}>
          <input
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            placeholder="title"
            aria-label="note title"
          />
          <input
            value={body}
            onChange={(e) => setBody(e.target.value)}
            placeholder="body"
            aria-label="note body"
          />
          <button type="submit" disabled={busy}>
            {busy ? "saving…" : "Add"}
          </button>
        </form>
      </section>

      <section className="panel">
        <h2>Your notes — query, answered locally</h2>
        {notes.length === 0 && <p className="reply">No notes yet.</p>}
        {notes.map((note) =>
          editingId === note.id ? (
            <form
              key={note.id}
              style={{ flexWrap: "wrap" }}
              onSubmit={(e) => {
                e.preventDefault();
                void onSaveEdit(note.id);
              }}
            >
              <input
                value={editTitle}
                onChange={(e) => setEditTitle(e.target.value)}
              />
              <input
                value={editBody}
                onChange={(e) => setEditBody(e.target.value)}
              />
              <button type="submit" disabled={busy}>Save</button>
              <button type="button" onClick={() => setEditingId(null)}>
                Cancel
              </button>
            </form>
          ) : (
            <div key={note.id} className="panel">
              <h2>{note.title}</h2>
              <p className="reply">{note.body}</p>
              <button onClick={() => startEdit(note)} style={{ marginRight: "0.5rem" }}>
                Edit
              </button>
              <button onClick={() => onDelete(note.id)} disabled={busy}>
                Delete
              </button>
            </div>
          )
        )}
      </section>
      {error && <p className="error">{error}</p>}

      <footer>served from the chain · post-quantum certified · Thebes</footer>
    </main>
  );
}