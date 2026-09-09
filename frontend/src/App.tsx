import { useEffect, useState } from "react";
import {
  call,
  encodeEmpty,
  encodeText,
  encodeTextNat,
  encodeTextNatTextText,
  encodeTextTextNat,
  encodeTextTextText,
  query,
} from "./thebes";
import { useTheme } from "./useTheme";
import { useMemphis } from "./useMemphis";
import MemphisGate from "./MemphisGate";

type Note = { id: number; title: string; body: string; shared: boolean };
type FeedItem = { id: number; owner: string; title: string; body: string };
type TipRecord = { from: string; to: string; amount: number };
type Seal = { members: number; circulation: number; expected: number; consistent: boolean };

export default function App() {
  const theme = useTheme();
  const auth = useMemphis();
  const owner = auth.session?.anchor_id_hex ?? "";

  const [notes, setNotes] = useState<Note[]>([]);
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [editingId, setEditingId] = useState<number | null>(null);
  const [editTitle, setEditTitle] = useState("");
  const [editBody, setEditBody] = useState("");

  const [balance, setBalance] = useState<number | null>(null);
  const [feed, setFeed] = useState<FeedItem[]>([]);
  const [tipHistory, setTipHistory] = useState<TipRecord[]>([]);
  const [tipAmounts, setTipAmounts] = useState<Record<number, string>>({});
  const [seal, setSeal] = useState<Seal | null>(null);

  async function refreshNotes() {
    if (!owner) return;
    try {
      const raw = await query("list", encodeText(owner));
      setNotes(JSON.parse(String(raw)) as Note[]);
      setError(null);
    } catch (e) {
      setError(String(e));
    }
  }

  async function refreshBalance() {
    if (!owner) return;
    try {
      const v = await call("balance", encodeText(owner));
      setBalance(typeof v === "bigint" ? Number(v) : null);
    } catch (e) {
      setError(String(e));
    }
  }

  async function refreshFeed() {
    try {
      const raw = await query("feed", encodeEmpty());
      setFeed(JSON.parse(String(raw)) as FeedItem[]);
    } catch (e) {
      setError(String(e));
    }
  }

  async function refreshTipHistory() {
    if (!owner) return;
    try {
      const raw = await query("tipHistory", encodeText(owner));
      setTipHistory(JSON.parse(String(raw)) as TipRecord[]);
    } catch (e) {
      setError(String(e));
    }
  }

  async function refreshSeal() {
    try {
      const raw = await query("ledgerSealView", encodeEmpty());
      setSeal(JSON.parse(String(raw)) as Seal);
    } catch (e) {
      setError(String(e));
    }
  }

  useEffect(() => {
    void refreshFeed();
    void refreshSeal();
  }, []);

  useEffect(() => {
    if (!owner) {
      setNotes([]);
      setBalance(null);
      setTipHistory([]);
      setError(null);
      setTitle("");
      setBody("");
      return;
    }
    void refreshNotes();
    void refreshBalance();
    void refreshTipHistory();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [owner]);

  async function onAdd(e: React.FormEvent) {
    e.preventDefault();
    if (!owner || !title.trim()) return;
    setError(null);
    setBusy(true);
    try {
      await call("add", encodeTextTextText(owner, title, body));
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
    if (!owner) return;
    setError(null);
    setBusy(true);
    try {
      await call("edit", encodeTextNatTextText(owner, id, editTitle, editBody));
      setEditingId(null);
      await refreshNotes();
    } catch (e) {
      setError(String(e));
    } finally {
      setBusy(false);
    }
  }

  async function onDelete(id: number) {
    if (!owner) return;
    setError(null);
    setBusy(true);
    try {
      await call("remove", encodeTextNat(owner, id));
      await refreshNotes();
      await refreshFeed();
    } catch (e) {
      setError(String(e));
    } finally {
      setBusy(false);
    }
  }

  async function onToggleShare(note: Note) {
    if (!owner) return;
    setError(null);
    setBusy(true);
    try {
      await call(note.shared ? "unshare" : "share", encodeTextNat(owner, note.id));
      await refreshNotes();
      await refreshFeed();
    } catch (e) {
      setError(String(e));
    } finally {
      setBusy(false);
    }
  }

  async function onTipFeedItem(item: FeedItem) {
    if (!owner) return;
    const raw = tipAmounts[item.id] ?? "10";
    const amount = Number(raw);
    if (!Number.isFinite(amount) || amount <= 0) {
      setError("Enter a positive tip amount");
      return;
    }
    setError(null);
    setBusy(true);
    try {
      const result = await call("tip", encodeTextTextNat(owner, item.owner, amount));
      const message = String(result);
      if (message) {
        setError(message);
      } else {
        await refreshBalance();
        await refreshTipHistory();
        await refreshSeal();
      }
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

      <MemphisGate auth={auth} />

      {auth.signedIn && (
        <>
          <section className="panel">
            <h2>Your balance</h2>
            <p className="count">
              <strong>{balance !== null ? balance : "…"}</strong> points
            </p>
          </section>

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
                  <p className="strap">{note.shared ? "shared to feed" : "private"}</p>
                  <button onClick={() => startEdit(note)} style={{ marginRight: "0.5rem" }}>
                    Edit
                  </button>
                  <button onClick={() => onDelete(note.id)} disabled={busy} style={{ marginRight: "0.5rem" }}>
                    Delete
                  </button>
                  <button onClick={() => void onToggleShare(note)} disabled={busy}>
                    {note.shared ? "Unshare" : "Share"}
                  </button>
                </div>
              )
            )}
          </section>

          <section className="panel">
            <h2>Public feed — shared notes from everybody</h2>
            {feed.length === 0 && <p className="reply">Nothing shared yet.</p>}
            {feed.map((item) => (
              <div key={`${item.owner}-${item.id}`} className="panel">
                <h2>{item.title}</h2>
                <p className="reply">{item.body}</p>
                <p className="strap">by {item.owner}</p>
                {item.owner !== owner && (
                  <form
                    style={{ flexWrap: "wrap" }}
                    onSubmit={(e) => {
                      e.preventDefault();
                      void onTipFeedItem(item);
                    }}
                  >
                    <input
                      value={tipAmounts[item.id] ?? "10"}
                      onChange={(e) =>
                        setTipAmounts((prev) => ({ ...prev, [item.id]: e.target.value }))
                      }
                      aria-label="tip amount"
                      style={{ maxWidth: "6rem" }}
                    />
                    <button type="submit" disabled={busy}>
                      Tip
                    </button>
                  </form>
                )}
              </div>
            ))}
          </section>

          <section className="panel">
            <h2>Tip history</h2>
            {tipHistory.length === 0 && <p className="reply">No tips yet.</p>}
            {tipHistory.map((t, i) => (
              <p key={i} className="reply">
                {t.from} → {t.to}: {t.amount}
              </p>
            ))}
          </section>
        </>
      )}

      {error && <p className="error">{error}</p>}

      <footer>
        served from the chain · post-quantum certified · Thebes
        {seal && (
          <p className="strap">
            ledger: {seal.circulation} / {seal.expected} ·{" "}
            {seal.consistent ? "consistent" : "⚠ INCONSISTENT"}
          </p>
        )}
      </footer>
    </main>
  );
}