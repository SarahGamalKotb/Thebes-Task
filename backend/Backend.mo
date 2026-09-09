// notes-app backend — a starter canister on the Thebes substrate.
//
// Two surfaces, mirroring the classic hello template:
//
//  * greet(name)   — a query: read-only, answered locally, no consensus.
//  * increment()   — an update: ordered by consensus, executed on every
//    validator. Every top-level `var` here survives upgrades.
//  * get_count()   — the counter's query.
//
// ⚠ UPGRADES DO NOT PRESERVE STATE (Motoko, today).
//
// moc's default is enhanced orthogonal persistence: your data lives in the
// wasm's MAIN memory, and surviving an upgrade depends on the platform
// preserving that. Thebes preserves STABLE memory and hands the upgraded
// canister a fresh instance — so `thebes-deploy deploy --upgrade` silently
// resets everything here. Verified on-chain: a counter at 3 read 0 after
// an upgrade.
//
// The usual fix, `moc --legacy-persistence` (classic stable-memory
// persistence), does NOT work here either: it emits a wasm32 module the
// substrate refuses to instantiate ("incompatible import type for
// ic0::call_data_append"). So there is currently no Motoko configuration
// on Thebes that both installs AND survives an upgrade.
//
// Until the substrate closes that gap: treat a Motoko upgrade as a reset,
// or use the Rust backend, whose ic-stable-structures state lives in
// stable memory and does survive.

/*
persistent actor Backend {
  var count : Nat = 0;

  public query func greet(name : Text) : async Text {
    "Greetings, " # name # " — from notes-app, live on Thebes."
  };

  public func increment() : async Nat {
    count += 1;
    count
  };

  public query func get_count() : async Nat {
    count
  };
};
*/

import Map "mo:core/Map";
import Nat "mo:core/Nat";
import Text "mo:core/Text";

persistent actor Backend {

  public type Note = {
    id : Nat;
    title : Text;
    body : Text;
    isShared : Bool;
  };

  public type Tip = {
    from : Text;
    to : Text;
    amount : Nat;
  };

  let STARTING_POINTS : Nat = 100;

  var nextId : Nat = 0;
  let shelves = Map.empty<Text, Map.Map<Nat, Note>>();

  let balances = Map.empty<Text, Nat>();
  let joined = Map.empty<Text, Bool>();

  var nextTipId : Nat = 0;
  let tips = Map.empty<Nat, Tip>();

  // ── helpers ──────────────────────────────────────────────

  func shelfOrNew(owner : Text) : Map.Map<Nat, Note> {
    switch (Map.get(shelves, Text.compare, owner)) {
      case (?s) { s };
      case null {
        let s = Map.empty<Nat, Note>();
        Map.add(shelves, Text.compare, owner, s);
        s
      };
    }
  };

  // Grants the starting points once. Never re-grants — that is why we
  // track `joined` separately instead of checking balance == 0 (someone
  // who spent everything would otherwise get another 100).
  func ensureJoined(owner : Text) {
    switch (Map.get(joined, Text.compare, owner)) {
      case (?_) { };
      case null {
        Map.add(joined, Text.compare, owner, true);
        Map.add(balances, Text.compare, owner, STARTING_POINTS);
      };
    }
  };

  func balanceOf(owner : Text) : Nat {
    switch (Map.get(balances, Text.compare, owner)) {
      case (?b) { b };
      case null { 0 };
    }
  };

  func boolToText(b : Bool) : Text {
    if (b) { "true" } else { "false" }
  };

  func noteToJson(n : Note) : Text {
    "{\"id\":" # Nat.toText(n.id) #
    ",\"title\":\"" # n.title # "\"" #
    ",\"body\":\"" # n.body # "\"" #
    ",\"shared\":" # boolToText(n.isShared) # "}"
  };

  func feedItemToJson(owner : Text, n : Note) : Text {
    "{\"id\":" # Nat.toText(n.id) #
    ",\"owner\":\"" # owner # "\"" #
    ",\"title\":\"" # n.title # "\"" #
    ",\"body\":\"" # n.body # "\"}"
  };

  func tipToJson(t : Tip) : Text {
    "{\"from\":\"" # t.from # "\"" #
    ",\"to\":\"" # t.to # "\"" #
    ",\"amount\":" # Nat.toText(t.amount) # "}"
  };

  // ── notes (from Task 1/2) ────────────────────────────────

  public func add(owner : Text, title : Text, body : Text) : async Nat {
    ensureJoined(owner);
    let id = nextId;
    nextId += 1;
    Map.add(shelfOrNew(owner), Nat.compare, id, { id; title; body; isShared = false });
    id
  };

  public query func list(owner : Text) : async Text {
    switch (Map.get(shelves, Text.compare, owner)) {
      case null { "[]" };
      case (?s) {
        var out = "[";
        var first = true;
        for (n in Map.values(s)) {
          if (not first) { out #= "," };
          out #= noteToJson(n);
          first := false;
        };
        out # "]"
      };
    }
  };

  public func edit(owner : Text, id : Nat, title : Text, body : Text) : async Bool {
    switch (Map.get(shelves, Text.compare, owner)) {
      case null { false };
      case (?s) {
        switch (Map.get(s, Nat.compare, id)) {
          case (?existing) {
            Map.add(s, Nat.compare, id, { id; title; body; isShared = existing.isShared });
            true
          };
          case null { false };
        }
      };
    }
  };

  public func remove(owner : Text, id : Nat) : async Bool {
    switch (Map.get(shelves, Text.compare, owner)) {
      case null { false };
      case (?s) {
        switch (Map.get(s, Nat.compare, id)) {
          case (?_existing) {
            Map.remove(s, Nat.compare, id);
            true
          };
          case null { false };
        }
      };
    }
  };

  // ── share / unshare (Task 3) ─────────────────────────────

  public func share(owner : Text, id : Nat) : async Bool {
    switch (Map.get(shelves, Text.compare, owner)) {
      case null { false };
      case (?s) {
        switch (Map.get(s, Nat.compare, id)) {
          case (?existing) {
            Map.add(s, Nat.compare, id, { existing with isShared = true });
            true
          };
          case null { false };
        }
      };
    }
  };

  public func unshare(owner : Text, id : Nat) : async Bool {
    switch (Map.get(shelves, Text.compare, owner)) {
      case null { false };
      case (?s) {
        switch (Map.get(s, Nat.compare, id)) {
          case (?existing) {
            Map.add(s, Nat.compare, id, { existing with isShared = false });
            true
          };
          case null { false };
        }
      };
    }
  };

  // query — every shared note, from everybody, with its owner attached
  public query func feed() : async Text {
    var out = "[";
    var first = true;
    for ((owner, s) in Map.entries(shelves)) {
      for (n in Map.values(s)) {
        if (n.isShared) {
          if (not first) { out #= "," };
          out #= feedItemToJson(owner, n);
          first := false;
        };
      };
    };
    out # "]"
  };

  // ── points ledger (Task 3) ───────────────────────────────

  // Not `query`: the first call for a new owner grants the starting
  // points, which changes state.
  public func balance(owner : Text) : async Nat {
    ensureJoined(owner);
    balanceOf(owner)
  };

  public func tip(from : Text, to : Text, amount : Nat) : async Text {
    ensureJoined(from);
    ensureJoined(to);
    if (from == to) { return "You cannot tip yourself" };
    let fromBal = balanceOf(from);
    if (fromBal < amount) { return "Not enough points" };
    Map.add(balances, Text.compare, from, fromBal - amount);
    Map.add(balances, Text.compare, to, balanceOf(to) + amount);
    let id = nextTipId;
    nextTipId += 1;
    Map.add(tips, Nat.compare, id, { from; to; amount });
    ""
  };

  // query — every tip that mentions `owner`, either side
  public query func tipHistory(owner : Text) : async Text {
    var out = "[";
    var first = true;
    for (t in Map.values(tips)) {
      if (t.from == owner or t.to == owner) {
        if (not first) { out #= "," };
        out #= tipToJson(t);
        first := false;
      };
    };
    out # "]"
  };

  // query — bonus: the invariant. sum of all balances must equal
  // 100 × members, always. Put this in the footer.
  public query func ledgerSealView() : async Text {
    var circulation = 0;
    for (b in Map.values(balances)) { circulation += b };
    let members = Map.size(joined);
    let expected = members * STARTING_POINTS;
    "{\"members\":" # Nat.toText(members) #
    ",\"circulation\":" # Nat.toText(circulation) #
    ",\"expected\":" # Nat.toText(expected) #
    ",\"consistent\":" # boolToText(circulation == expected) # "}"
  };
};