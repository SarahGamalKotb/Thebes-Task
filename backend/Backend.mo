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

persistent actor Backend {

  public type Note = {
    id : Nat;
    title : Text;
    body : Text;
  };

  var nextId : Nat = 0;
  let notes = Map.empty<Nat, Note>();

  func noteToJson(n : Note) : Text {
    "{\"id\":" # Nat.toText(n.id) #
    ",\"title\":\"" # n.title # "\"" #
    ",\"body\":\"" # n.body # "\"}"
  };

  // update — creates a note
  public func add(title : Text, body : Text) : async Nat {
    let id = nextId;
    nextId += 1;
    Map.add(notes, Nat.compare, id, { id; title; body });
    id
  };

  // query — returns ALL notes as one JSON-array string
  public query func list() : async Text {
    var out = "[";
    var first = true;
    for (n in Map.values(notes)) {
      if (not first) { out #= "," };
      out #= noteToJson(n);
      first := false;
    };
    out # "]"
  };

  // update — edits an existing note
  public func edit(id : Nat, title : Text, body : Text) : async Bool {
    switch (Map.get(notes, Nat.compare, id)) {
      case (?_existing) {
        Map.add(notes, Nat.compare, id, { id; title; body });
        true
      };
      case null { false };
    }
  };

  // update — deletes a note
  public func remove(id : Nat) : async Bool {
    switch (Map.get(notes, Nat.compare, id)) {
      case (?_existing) {
        Map.remove(notes, Nat.compare, id);
        true
      };
      case null { false };
    }
  };
};