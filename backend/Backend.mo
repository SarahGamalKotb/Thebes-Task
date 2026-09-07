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
  };

  var nextId : Nat = 0;
  let shelves = Map.empty<Text, Map.Map<Nat, Note>>();

  // Get owner's shelf, creating an empty one on first use.
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

  func noteToJson(n : Note) : Text {
    "{\"id\":" # Nat.toText(n.id) #
    ",\"title\":\"" # n.title # "\"" #
    ",\"body\":\"" # n.body # "\"}"
  };

  // update — creates a note on `owner`'s shelf
  public func add(owner : Text, title : Text, body : Text) : async Nat {
    let id = nextId;
    nextId += 1;
    Map.add(shelfOrNew(owner), Nat.compare, id, { id; title; body });
    id
  };

  // query — returns only `owner`'s notes as JSON. No shelf yet is not
  // an error — they simply have no notes.
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

  // update — edits a note, only if it exists on `owner`'s shelf
  public func edit(owner : Text, id : Nat, title : Text, body : Text) : async Bool {
    switch (Map.get(shelves, Text.compare, owner)) {
      case null { false };
      case (?s) {
        switch (Map.get(s, Nat.compare, id)) {
          case (?_existing) {
            Map.add(s, Nat.compare, id, { id; title; body });
            true
          };
          case null { false };
        }
      };
    }
  };

  // update — deletes a note, only if it exists on `owner`'s shelf
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
};