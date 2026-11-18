---
title: "How Tabletist is built: a native database client in Rust and egui"
description: "How a native database client is built in Rust and egui, from its own code: the rules the compiler holds, the tests that read the source, and UI tests without a screen."
layout: post
tags:
  - Rust
  - Tabletist
featured: true
hidden: true
toc: true
---

Tabletist is a database client for PostgreSQL, MySQL, SQLite and BigQuery. It is
written in Rust on egui, and it runs on Linux, macOS and Windows. This post
is about how it is built: the rules the compiler holds for me, the rules
tests hold by reading the source, how I test a GUI without a screen, and
where the code is still only as good as review.

Everything quoted here is real code from the repository, linked at the
commit it came from.

<!--more-->

## Why native, and what it costs

When I moved to Omarchy, a Hyprland setup where everything is driven
from the keyboard and follows one theme, no database client felt at home
there. I wanted a
client that looks like the rest of my desktop on Omarchy, and like a Mac
app on my Mac.

So I built one on egui, an immediate-mode GUI library for Rust, through
eframe, its app framework. There is no browser inside. One codebase builds
a binary for each of the three systems, and the window is drawn with
OpenGL:

[Cargo.toml, lines 50 to 55](https://github.com/igor-alexandrov/tabletist/blob/2294c3d1e8b65efedaa32b872720c4cea65a2cae/Cargo.toml#L50-L55)

```toml
# The whole UI. glow keeps the binary and dependency tree small; a 2D table
# browser does not need wgpu. AccessKit exposes controls to screen readers and
# to the headless tests. `links` opens the About dialog's link to the source
# in the browser, through webbrowser: the one crate it adds, since its own
# (url, log, objc2) are in the tree already.
eframe = { version = "0.36", default-features = false, features = ["accesskit", "default_fonts", "glow", "links", "persistence", "wayland", "x11"] }
```

Most dependencies in `Cargo.toml` have a comment like that one, saying
why they are there.

The binary is not tiny. The Linux x86_64 binary of v0.5.0 is 43.2 MiB
stripped, with SQLite and rustls inside it, and an 18.4 MiB `.tar.gz`
download. It is quick to start and modest to run, though. On my machine
(a Ryzen AI MAX+ 395 on Omarchy), launched with the demo database, v0.5.0
commits its first frame in 108 ms and has the demo's table drawn and
settled in 136 ms, the median of 20 warm runs. Idle on the demo it uses
131.7 MiB of RSS, 87.9 MiB of it PSS. The method, the raw runs, and the
same numbers for the AppImage and for cold starts are in
[`contrib/measure`](https://github.com/igor-alexandrov/tabletist/blob/2294c3d1e8b65efedaa32b872720c4cea65a2cae/contrib/measure/README.md),
so anyone can take them again.

The same code draws three looks: one for Windows, one for macOS, and
Omarchy's, which is keyboard-first and follows the desktop's theme and
font as it changes. On Linux outside Omarchy, the app draws the macOS
look with the Windows keys. The three are one list:

[crates/tabletist-core/src/theme.rs, line 504](https://github.com/igor-alexandrov/tabletist/blob/2294c3d1e8b65efedaa32b872720c4cea65a2cae/crates/tabletist-core/src/theme.rs#L504)

```rust
    pub const ALL: [Look; 3] = [Self::standard(), Self::macos(), Self::omarchy()];
```

{% include image-caption.html imageurl="https://igor.works/tabletist/assets/images/omarchy-table.webp" title="Tabletist in its Omarchy look: the Bookshop demo database's book_covers table, with the sidebar of tables on the left and the row panel on the right" caption="Omarchy's look, on the Bookshop demo database." %}

The keys differ too. The Mac and Windows looks share one set of keys
(Ctrl for Cmd on Windows), and Omarchy has its own, closer to vim.

egui gave me a lot for free, and some things not at all. In an
immediate-mode library every frame is a function call that draws
everything again. That makes a view easy to write and easy to test. It
also means text, keyboard focus and accessibility are mine to get right,
everywhere, every frame.

Two rules came out of that. A view never names a font, a family or a size.
It names a role, and the role knows its face and size in each look:

[src/typography.rs, lines 64 to 78](https://github.com/igor-alexandrov/tabletist/blob/2294c3d1e8b65efedaa32b872720c4cea65a2cae/src/typography.rs#L64-L78)

```rust
pub enum TextRole {
    // macOS, from the spec.
    UiBody,
    UiBodyStrong,
    TableTitle,
    ScreenTitle,
    DialogTitle,
    SectionLabel,
    Secondary,
    FieldLabel,
    ColumnType,
    GridCell,
    Json,
    Tag,
    Shortcut,
```

That is the start of the list. There are 43 roles in all, and a view uses
them like this:

[src/ui/calendar.rs, line 455](https://github.com/igor-alexandrov/tabletist/blob/2294c3d1e8b65efedaa32b872720c4cea65a2cae/src/ui/calendar.rs#L455)

```rust
    let laid = Text::one(look, TextRole::UiBodySemibold, &title, palette.text).layout(ui.ctx());
```

The second rule is that keyboard focus is drawn in one place, after
everything else, for whatever has the keyboard. A view that drew its own
ring would sooner or later forget one:

[src/ui/focus.rs, lines 1 to 4](https://github.com/igor-alexandrov/tabletist/blob/2294c3d1e8b65efedaa32b872720c4cea65a2cae/src/ui/focus.rs#L1-L4)

```rust
//! Keyboard focus, shown: a ring round whatever has the keyboard, once the
//! keyboard (not the pointer) put it there. One painter draws it for every
//! widget, egui's own included, so no Tab stop is ever without one; a
//! widget that wants another form than the default says so with [`hint`].
```

I will be honest about these two: nothing but review enforces them. Today
no view outside `src/typography.rs` builds a `FontId` of its own or names
a `FontFamily`, but no test would fail if one did. The rules below are the
ones I do not have to remember.

## Rules the compiler holds

Where I can, a rule is a compile error. That holds for me, for anyone who
sends a pull request, and for a coding agent working in the repository.

### `unsafe` lives in three small crates

The workspace forbids `unsafe`:

[Cargo.toml, lines 13 to 14](https://github.com/igor-alexandrov/tabletist/blob/2294c3d1e8b65efedaa32b872720c4cea65a2cae/Cargo.toml#L13-L14)

```toml
[workspace.lints.rust]
unsafe_code = "forbid"
```

Some calls cannot be made without it. CoreText lists the installed fonts
through C statics and untyped collections. The macOS menu bar needs an
Objective-C delegate for `NSMenu`, and on Windows muda attaches the bar by
subclassing the window, a call it marks unsafe. SQLite hands back column
names as bytes that may not be UTF-8, and its authorizer is a C callback.

Those calls live in three crates: `tabletist-appkit` (the CoreText fonts,
despite the name), `tabletist-menubar` and `tabletist-sqlite-ffi`. Each
one lowers the lint from `forbid` to `deny`, and says why in its manifest:

[crates/tabletist-sqlite-ffi/Cargo.toml, lines 9 to 23](https://github.com/igor-alexandrov/tabletist/blob/2294c3d1e8b65efedaa32b872720c4cea65a2cae/crates/tabletist-sqlite-ffi/Cargo.toml#L9-L23)

```toml
# The workspace forbids unsafe code. rusqlite reads a result column's name and
# declared type as `str` and panics when their bytes are not UTF-8, which a
# file can hold, and it keeps the statement's pointer to itself. Its
# authorizer reads the names SQLite asks about the same way. The bytes can
# only be read through SQLite's C API, so this crate carries the workspace's
# lints with `unsafe_code` lowered to `deny`, allowed only in the files that
# make those calls (`columns.rs`, `authorizer.rs` and the tests' `testing.rs`),
# each use with a SAFETY note. The app and the database layer keep `forbid`.
[lints.rust]
unsafe_code = "deny"

[lints.clippy]
unwrap_used = "warn"
# An `unsafe` block or impl without a SAFETY note above it fails the build.
undocumented_unsafe_blocks = "deny"
```

The difference between the two levels is the whole trick. An inner
`#[allow(unsafe_code)]` cannot lift a `forbid`: rustc refuses it. It can
lift a `deny`. So in these three crates a file has to opt in with
`#![allow(unsafe_code)]` at its top, and every other file in the crate
still cannot hold `unsafe`. Six files opt in. Between them they hold 35
`unsafe` blocks, 2 `unsafe impl`s and 4 `unsafe fn`s. The workspace's
other four crates (the app, its core, the database layer and the MCP
server) hold none.

Here is the one I find most interesting, from the SQLite authorizer. A
Rust closure goes to SQLite as a raw pointer, and the SAFETY notes are
where I keep track of who owns the box at each step:

[crates/tabletist-sqlite-ffi/src/authorizer.rs, lines 146 to 186](https://github.com/igor-alexandrov/tabletist/blob/2294c3d1e8b65efedaa32b872720c4cea65a2cae/crates/tabletist-sqlite-ffi/src/authorizer.rs#L146-L186)

```rust
pub fn set_authorizer<F>(connection: &rusqlite::Connection, authorizer: F) -> rusqlite::Result<()>
where
    F: Fn(&Action<'_>) -> Authorization + Send + 'static,
{
    // SAFETY: the handle is used only below, while `connection` is borrowed.
    // A connection is not `Sync`, so no other thread prepares a statement on
    // it meanwhile.
    let db = unsafe { connection.handle() };
    let callback = Box::into_raw(Box::new(authorizer)).cast::<c_void>();
    // SAFETY: `db` is an open connection. `ask::<F>` gets `callback`, which
    // points to an `F` that lives until `free::<F>` drops it, and that is
    // not before SQLite has stopped calling `ask::<F>` with it: see below.
    // `F` is `Send`, so it may be called on whichever thread the connection
    // moves to.
    let code = unsafe { ffi::sqlite3_set_authorizer(db, Some(ask::<F>), callback) };
    if code != ffi::SQLITE_OK {
        // SAFETY: SQLite did not take the pointer, so the box made above is
        // still this function's to free.
        drop(unsafe { Box::from_raw(callback.cast::<F>()) });
        return Err(failure(code, None));
    }
    // SAFETY: `db` is an open connection and the name is a NUL-terminated
    // string, which SQLite copies. SQLite calls `free::<F>` with `callback`
    // once: when other data is kept under the name or when the connection
    // closes. Either way nothing calls the authorizer by then: this function
    // and `remove_authorizer` point SQLite away from it first, and a closed
    // connection prepares nothing. The authorizer this one replaces is freed
    // here the same way, by the `free` it was kept with, after the call
    // above took it out of use.
    let code =
        unsafe { ffi::sqlite3_set_clientdata(db, KEPT_AS.as_ptr(), callback, Some(free::<F>)) };
    if code != ffi::SQLITE_OK {
        // SQLite frees what it cannot keep, so the callback is gone and
        // nothing may call it.
        // SAFETY: `db` is an open connection, and no callback with no
        // argument takes the authorizer off.
        unsafe { ffi::sqlite3_set_authorizer(db, None, ptr::null_mut()) };
        return Err(failure(code, None));
    }
    Ok(())
}
```

Every `unsafe` block in the three crates has a SAFETY note like these.
That is not left to memory either: the manifest above, like the other two,
denies `clippy::undocumented_unsafe_blocks`, so an `unsafe` block or impl
without a note fails the build.

### Every engine is decided for

Tabletist speaks to four engines, and a lot of code depends on which. The
rule is that such code matches on `Driver` or `Dialect` and names every
variant:

[crates/tabletist-db/src/spec.rs, lines 11 to 29](https://github.com/igor-alexandrov/tabletist/blob/2294c3d1e8b65efedaa32b872720c4cea65a2cae/crates/tabletist-db/src/spec.rs#L11-L29)

```rust
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Default, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Driver {
    #[default]
    Postgres,
    #[serde(rename = "mysql")]
    MySql,
    Sqlite,
    BigQuery,
}

impl Driver {
    pub fn default_port(self) -> u16 {
        match self {
            Self::Postgres => 5432,
            Self::MySql => 3306,
            Self::Sqlite | Self::BigQuery => 0,
        }
    }
```

A new engine then fails to compile in every place like this, until
someone decides what it does there. That stopped being a thought
experiment when BigQuery came in as the fourth engine. BigQuery support
came from [@brianstarke](https://github.com/brianstarke)
([#266](https://github.com/igor-alexandrov/tabletist/pull/266)), and every
match like the one above now has a BigQuery arm. The same goes for the enums
behind them. This is how the database layer runs an agent's read:

[crates/tabletist-db/src/lib.rs, lines 304 to 309](https://github.com/igor-alexandrov/tabletist/blob/2294c3d1e8b65efedaa32b872720c4cea65a2cae/crates/tabletist-db/src/lib.rs#L304-L309)

```rust
        let (outcome, masked) = match &self.inner {
            Inner::Sqlite(conn) => conn.run_read(read, limits, sources, stop).await,
            Inner::Postgres(conn) => conn.run_read(read, limits, sources, stop).await,
            Inner::MySql(conn) => conn.run_read(read, limits, sources, stop).await,
            Inner::BigQuery(conn) => conn.run_read(read, limits, sources, stop).await,
        }?;
```

An `if driver == Driver::Sqlite` would compile today and quietly give a
fifth engine the `else` branch. The compiler cannot stop that, since
`Driver` derives `PartialEq`. A test does, in the next section.

### The core cannot draw

The app's state and its edits, the backend, the settings and the keymap
live in their own crate, `tabletist-core`. The app's crate, with the views
and the window, stands on it. The core needs a few of egui's data types,
but it must never draw. The compiler holds part of that: the core cannot
name the app's crate, since it does not depend on it. A test holds the
rest:

[crates/tabletist-core/tests/interface.rs, lines 1 to 8](https://github.com/igor-alexandrov/tabletist/blob/2294c3d1e8b65efedaa32b872720c4cea65a2cae/crates/tabletist-core/tests/interface.rs#L1-L8)

```rust
//! The core stays off the interface. It depends on egui for three data
//! types (`Key`, `Color32`, `FontData`), because fastframe-theme stands on
//! egui anyway, but it never draws: no crate of the window, the widgets or
//! the text they lay out in its `Cargo.toml`, and no `egui::Context`,
//! `egui::Ui`, `egui::Painter` or `egui::Response` in its sources, tests
//! included. What sets up egui or draws on it is the `tabletist` crate's.
//! That the core names nothing of the interface the compiler holds: this
//! crate does not depend on that one.
```

That test reads the core's manifest and its sources as text, the way the
tests in the next section do. So nothing in the core, its own tests
included, can reach for a window, even by accident.

### A key is something only the keymap can write

Every key in the app is in one table, `BINDINGS` in
`crates/tabletist-core/src/keymap.rs`: each
command, the scopes it holds in (the grid, the SQL editor, a dialog), and
its keys for the Mac look and for Omarchy. Windows takes the Mac's keys
with Ctrl for Cmd, unless a line gives it keys of its own.

[crates/tabletist-core/src/keymap.rs, lines 1394 to 1412](https://github.com/igor-alexandrov/tabletist/blob/2294c3d1e8b65efedaa32b872720c4cea65a2cae/crates/tabletist-core/src/keymap.rs#L1394-L1412)

```rust
pub const BINDINGS: &[Binding] = {
    use Command as C;
    &[
        // Window and connections.
        bind(
            C::Connections,
            GLOBAL,
            keys(&[k("cmd+o")]),
            // In a text field the chord is the field's copy: the only one
            // a cell's editor has, where Ctrl+C drops the edit.
            keys(&[k("ctrl+shift+c")]).normal(),
        ),
        bind(
            C::GoToConnectionWindow,
            GLOBAL,
            keys(&[k("cmd+1..9")]),
            keys(&[k("ctrl+shift+1..9")]),
        ),
        bind(C::SwitchDatabase, GLOBAL, NONE, keys(&[k("ctrl+shift+d")])),
```

The table has 337 entries for 315 commands. A command that is not built yet
is in it too, with its keys, so nothing else can take them.

Views do not compare key events. They ask the keymap whether a command's
key went down. And whatever paints a key beside a word, like a hint in a
footer or a button's shortcut, takes a `Written`:

[crates/tabletist-core/src/keymap.rs, lines 3276 to 3280](https://github.com/igor-alexandrov/tabletist/blob/2294c3d1e8b65efedaa32b872720c4cea65a2cae/crates/tabletist-core/src/keymap.rs#L3276-L3280)

```rust
/// A key as a layout writes it. Only the keymap makes one, so what paints
/// a key beside a word (a hint, a button's shortcut) can take nothing
/// written by hand.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Written(String);
```

Its field is private to the keymap module. A view cannot make one from a
string, so it cannot paint a key that the keymap did not write. When
someone rebinds a key in `settings.toml`, every hint changes with it.

## Rules tests hold by reading the source

Some rules the type system cannot say. For those I have tests that read the
`.rs` files as text. There are three of them, and they share one habit:
each tests its own scan, so it cannot pass just by finding nothing.

### No comparing an engine

`tests/engines.rs` reads every Rust file of the app, its core, the
database layer and the MCP server. It drops comment lines and each file's `tests` module,
joins the rest onto one line so a comparison split over lines reads as
one, and looks for a variant compared with `==`, `!=` or inside
`matches!`:

[tests/engines.rs, lines 195 to 213](https://github.com/igor-alexandrov/tabletist/blob/2294c3d1e8b65efedaa32b872720c4cea65a2cae/tests/engines.rs#L195-L213)

```rust
#[test]
fn no_code_compares_a_driver_or_a_dialect() {
    // A comparison gives an engine added later the other side's answer
    // without anyone choosing it. A `match` that names every engine does
    // not compile until someone has.
    let found: Vec<String> = sources()
        .iter()
        .flat_map(|(path, text)| {
            comparisons(&code(text))
                .into_iter()
                .map(move |found| format!("{path}: {found}"))
        })
        .collect();
    assert!(
        found.is_empty(),
        "match on every engine instead:\n{}",
        found.join("\n")
    );
}
```

And here is part of the test of the scan itself. These are texts it has to
find:

[tests/engines.rs, lines 160 to 173](https://github.com/igor-alexandrov/tabletist/blob/2294c3d1e8b65efedaa32b872720c4cea65a2cae/tests/engines.rs#L160-L173)

```rust
#[test]
fn the_scan_finds_each_way_to_compare() {
    for text in [
        "if spec.driver == Driver::Sqlite {",
        "let remote = tabletist_db::Driver::Sqlite != workspace.driver;",
        "b'#' if dialect\n    == Dialect::MySql => comment(),",
        "if matches!(self.dialect, Dialect::Postgres | Dialect::Sqlite) {",
        "if matches!(driver.dialect(), Dialect::MySql) {",
        "if Dialect::Ms_Sql == dialect {",
        "if driver == (Driver::Sqlite) {",
        "if (Dialect::MySql) != dialect {",
        "#[cfg(test)]\nmod helpers;\n\nfn file(driver: Driver) -> bool {\n    driver == Driver::Sqlite\n}",
        "let file = saved.map(|saved| saved.driver) == Some(Driver::Sqlite);",
        "if drivers.iter().any(|driver| driver == &Driver::Sqlite) {",
```

It has holes, and I would rather list them than have someone find them in
the comments. A `_ =>` arm is not caught: it compiles, and it gives a new
engine an answer nobody chose. A comparison written with `Self::` inside
the enums' own methods is not caught. And comparing two values with each
other, like `read.dialect() != self.dialect()`, passes on purpose: a new
engine gets the right answer from it. The rule is about comparing with a
variant.

### No key spelled by hand

`tests/keys.rs` looks at every string literal in the app's code (tests
and screenshot scenes aside) and fails on one that spells a key anywhere
but the keymap:

[tests/keys.rs, lines 12 to 15](https://github.com/igor-alexandrov/tabletist/blob/2294c3d1e8b65efedaa32b872720c4cea65a2cae/tests/keys.rs#L12-L15)

```rust
const SPELLED: [&str; 18] = [
    "ctrl+", "Ctrl+", "cmd+", "Cmd+", "Cmd/", "alt+", "Alt+", "shift+", "Shift+", "Mod+", "⌘", "⇧",
    "⌥", "⌃", "↩", "⌫", "⌦", "⇥",
];
```

[tests/keys.rs, lines 151 to 172](https://github.com/igor-alexandrov/tabletist/blob/2294c3d1e8b65efedaa32b872720c4cea65a2cae/tests/keys.rs#L151-L172)

```rust
#[test]
fn no_key_is_spelled_outside_the_keymap() {
    let mut found = Vec::new();
    for (name, text) in sources() {
        if MAY.contains(&name.as_str()) || TESTS.contains(&name.as_str()) {
            continue;
        }
        let code = tests_start(&text).map_or(text.as_str(), |at| &text[..at]);
        for (number, line) in code.lines().enumerate() {
            for literal in literals(line) {
                if SPELLED.iter().any(|spelled| literal.contains(spelled)) {
                    found.push(format!("{name}:{}: {literal:?}", number + 1));
                }
            }
        }
    }
    assert!(
        found.is_empty(),
        "keys written by hand, where the keymap should be asked:\n{}",
        found.join("\n")
    );
}
```

This catches the usual slip, a tooltip that says "Cmd+F" in its own words.
It does not catch a bare `"d"` or `"Enter"`. That is what `Written` is for.

The keymap tests itself from its own data too. This one walks every pair
of entries, in every layout, and fails when two commands share a key where
both could be read: the same scope or scopes that hold together, the same
condition, and modes that overlap:

[crates/tabletist-core/src/keymap.rs, lines 4881 to 4905](https://github.com/igor-alexandrov/tabletist/blob/2294c3d1e8b65efedaa32b872720c4cea65a2cae/crates/tabletist-core/src/keymap.rs#L4881-L4905)

```rust
    #[test]
    fn no_two_commands_share_a_key_where_both_could_be_read() {
        let keymap = Keymap::default();
        for layout in Layout::ALL {
            let entries = entries(&keymap, layout);
            for (index, a) in entries.iter().enumerate() {
                for b in &entries[index + 1..] {
                    let together =
                        a.scope.alongside(b.scope) && a.when == b.when && a.mode.overlaps(b.mode);
                    assert!(
                        a.command == b.command
                            || !together
                            || !clash(layout, &a.spelled, &b.spelled),
                        "{layout:?}: {} ({:?}, {}) and {} ({:?}, {})",
                        a.keys,
                        a.command,
                        a.scope.id(),
                        b.keys,
                        b.command,
                        b.scope.id(),
                    );
                }
            }
        }
    }
```

`clash` knows that `y` clashes with `yy p` (one is the start of the other),
that `alt+3` clashes with `alt+1..9`, and that on Windows `cmd+t` and
`ctrl+t` are the same key. Two commands sharing a key is a failing test
with both names in it, not a bug report.

### The MCP server never names a secret

The third one is in the MCP server's crate, and it is the shortest:

[crates/tabletist-mcp/tests/secrets.rs, lines 225 to 249](https://github.com/igor-alexandrov/tabletist/blob/2294c3d1e8b65efedaa32b872720c4cea65a2cae/crates/tabletist-mcp/tests/secrets.rs#L225-L249)

```rust
#[test]
fn the_crate_never_names_what_opens_a_database() {
    let mut files = Vec::new();
    sources(
        &Path::new(env!("CARGO_MANIFEST_DIR")).join("src"),
        &mut files,
    );
    assert!(files.len() >= 8, "{files:?}");
    for file in files {
        let text = std::fs::read_to_string(&file).unwrap();
        for name in [
            "ConnectSpec",
            "Secrets",
            "HostKeys",
            "connect_with",
            "Connection::connect",
        ] {
            assert!(
                !text.contains(name),
                "{} names {name}: the server reaches a database through its gateway alone",
                file.display()
            );
        }
    }
}
```

More on why in the MCP section.

## Testing a GUI without a screen

egui can run a frame without a window: you hand `egui::Context::run_ui` the
input for one frame, and you get back what it painted and, with AccessKit
on, the accessibility tree a screen reader would see. My test harness,
`src/testing.rs`, runs the whole app that way. A test clicks a control by
its accessible name, the way a screen reader asks for one:

[src/testing.rs, lines 283 to 308](https://github.com/igor-alexandrov/tabletist/blob/2294c3d1e8b65efedaa32b872720c4cea65a2cae/src/testing.rs#L283-L308)

```rust
    /// Clicks the widget labelled `label` through AccessKit: a button if
    /// there is one, else the sidebar's row of that table, view or group,
    /// else any node with that label (selectable labels and toggles get
    /// other roles).
    pub fn click(&mut self, label: &str) {
        let tree = self.settle();
        let target = node(&tree, label, Role::Button)
            .or_else(|| tree_row(&tree, label))
            .or_else(|| node(&tree, label, Role::Tab))
            .or_else(|| {
                tree.nodes
                    .iter()
                    .find(|(_, node)| node.label() == Some(label))
                    .map(|(id, _)| *id)
            })
            .unwrap_or_else(|| panic!("nothing labelled {label:?}: {:?}", labels(&tree)));
        self.frame(vec![egui::Event::AccessKitActionRequest(
            accesskit::ActionRequest {
                target_tree: accesskit::TreeId::ROOT,
                target_node: target,
                action: accesskit::Action::Click,
                data: None,
            },
        )]);
        self.settle();
    }
```

Key presses go in as egui events, one frame with the key down and one with
it up. The harness also keeps what the last frame painted (each piece of
text with its colour and place), so a test can check that a hint is drawn
in the right colour too.

The harness never connects to a database. The app's backend normally runs
on its own thread; in tests it is one that records:

[crates/tabletist-core/src/backend.rs, lines 688 to 711](https://github.com/igor-alexandrov/tabletist/blob/2294c3d1e8b65efedaa32b872720c4cea65a2cae/crates/tabletist-core/src/backend.rs#L688-L711)

```rust
    /// A backend with no thread: commands are recorded, events are injected.
    /// For reducer and UI tests.
    pub fn recording() -> Self {
        let (event_tx, event_rx) = mpsc::channel();
        Self {
            commands: None,
            events: event_rx,
            runtime: None,
            outbox: Outbox {
                events: event_tx,
                waker: Waker::default(),
            },
            #[cfg(any(test, feature = "testing"))]
            sent: Vec::new(),
            #[cfg(any(test, feature = "testing"))]
            saves: Vec::new(),
            #[cfg(any(test, feature = "testing"))]
            exports: Vec::new(),
            #[cfg(any(test, feature = "testing"))]
            export_asks: Vec::new(),
            #[cfg(test)]
            watched: Watched::default(),
        }
    }
```

A UI test checks which commands the app sent, and hands it the events a
database would have sent back. The engines have their own integration
tests, against real PostgreSQL, MySQL and MariaDB servers, which CI runs
on Linux.

Here is a whole test. It opens the connection picker with one saved
connection, then deletes it two ways (from the row's menu, and from the
connection's form) and checks that both ask first. It runs once for each
desktop look:

[src/ui/mod.rs, lines 3524 to 3542](https://github.com/igor-alexandrov/tabletist/blob/2294c3d1e8b65efedaa32b872720c4cea65a2cae/src/ui/mod.rs#L3524-L3542)

```rust
    #[test]
    fn a_rows_menu_and_the_connection_form_ask_before_deleting() {
        for look in desktop_looks() {
            // The row's menu.
            let mut harness = picker_with_one(look);
            harness.click("More actions for Bookshop");
            harness.click("Delete");
            assert!(asks_to_delete(&harness), "{}: the menu", look.name);
            assert_eq!(saved(&harness), 1, "{}: the menu", look.name);
            // The form's Delete closes the form, and the picker asks.
            let mut harness = picker_with_one(look);
            let conn = harness.app.connections.connections[0].id.clone();
            harness.app.apply(Action::EditConnection(conn));
            harness.click("Delete Bookshop");
            assert!(harness.app.dialog.is_none(), "{}", look.name);
            assert!(asks_to_delete(&harness), "{}: the form", look.name);
            assert_eq!(saved(&harness), 1, "{}: the form", look.name);
        }
    }
```

`asks_to_delete` reads the app's state:

[src/ui/mod.rs, lines 3190 to 3196](https://github.com/igor-alexandrov/tabletist/blob/2294c3d1e8b65efedaa32b872720c4cea65a2cae/src/ui/mod.rs#L3190-L3196)

```rust
    /// Whether the picker asks whether to delete a connection.
    fn asks_to_delete(harness: &Harness) -> bool {
        matches!(
            &harness.app.active_tab().content,
            crate::model::ConnTabContent::Picker(picker) if picker.deleting.is_some()
        )
    }
```

So the clicks go through AccessKit, by name, and the checks read the app.
A test that only reads the accessibility tree is possible too, but I don't
pretend every test is a screen reader test. What I get from this is that
every control a test can click has a name and a role, and a control
without one fails a test the day it is added.

The suite has 5,363 tests at v0.7.0, and 2,267 of them are the views' own,
in `src/ui`. CI runs them all on Linux, macOS and Windows.

## Views push actions, the app applies them

A view in Tabletist does not change the application's state. It pushes an
`Action`:

[crates/tabletist-core/src/model.rs, lines 50 to 65](https://github.com/igor-alexandrov/tabletist/blob/2294c3d1e8b65efedaa32b872720c4cea65a2cae/crates/tabletist-core/src/model.rs#L50-L65)

```rust
/// Everything that changes application state. Views push these; `App::apply`
/// applies them after the frame is drawn.
#[derive(Debug)]
pub enum Action {
    /// Cmd/Ctrl+O and the Connections button: show the saved connections,
    /// in the picker tab there is, or in a new one at the end.
    ShowConnections,
    CloseConnTab(ConnTabId),
    ActivateConnTab(ConnTabId),
    /// Cmd/Ctrl+1..9: activate the open connection at this position, as the
    /// header numbers them, if there is one.
    ActivateConnection(usize),
    /// Ctrl+Tab (+1) and Ctrl+Shift+Tab (-1), wrapping around.
    CycleConnTab(isize),
    /// A result from the backend.
    Backend(Event),
```

There are nearly 300 of them. The app applies them
until none are left, since one may queue more:

[src/app.rs, lines 967 to 979](https://github.com/igor-alexandrov/tabletist/blob/2294c3d1e8b65efedaa32b872720c4cea65a2cae/src/app.rs#L967-L979)

```rust
    /// Applies queued actions until none are left (an action may queue more).
    pub fn apply_actions(&mut self) {
        while !self.actions.is_empty() {
            for action in std::mem::take(&mut self.actions) {
                self.apply(action);
            }
        }
        self.read_reopened();
        self.format_rows();
        self.make_reviews();
        // Restart when done goes ahead in the frame the work ended in.
        self.tick_restart();
    }
```

A frame starts by taking what the backend finished and applying it:

[src/app.rs, lines 8894 to 8899](https://github.com/igor-alexandrov/tabletist/blob/2294c3d1e8b65efedaa32b872720c4cea65a2cae/src/app.rs#L8894-L8899)

```rust
    pub fn frame_ui(&mut self, ui: &mut egui::Ui) {
        self.focused = ui.ctx().input(|input| input.focused);
        self.note_use(ui.ctx());
        self.poll_backend();
        self.apply_actions();
        self.tick_lookups(ui.ctx());
```

and ends by drawing the views, painting the one focus ring over
everything, and applying what the views asked for:

[src/app.rs, lines 8933 to 8937](https://github.com/igor-alexandrov/tabletist/blob/2294c3d1e8b65efedaa32b872720c4cea65a2cae/src/app.rs#L8933-L8937)

```rust
        crate::ui::show(self, ui);
        // Over everything drawn: the ring of what has the keyboard.
        crate::ui::focus::paint(ui.ctx(), &self.look, &self.palette);
        crate::ui::keys::after_frame(ui.ctx());
        self.apply_actions();
```

A view gets to change two things directly: the text a field is editing,
and the cursor position that field reports. Everything else waits for
`apply`. This is what makes the tests above possible. A test can push an
`Action` and check the state, with no drawing at all, or click and check
the same state.

Database, network and disk work never runs on the UI thread:

[crates/tabletist-core/src/backend.rs, lines 1 to 2](https://github.com/igor-alexandrov/tabletist/blob/2294c3d1e8b65efedaa32b872720c4cea65a2cae/crates/tabletist-core/src/backend.rs#L1-L2)

```rust
//! The backend: a tokio runtime on its own thread. The UI sends commands and
//! polls events each frame; the backend wakes the UI when an event is ready.
```

The database layer, `crates/tabletist-db`, has no UI dependency at all.
It is tokio, the drivers (tokio-postgres, mysql_async, rusqlite, and
gcp-bigquery-client for BigQuery's REST API), russh for SSH tunnels, and
sqlparser.

## An MCP server that cannot leak a password

Tabletist can let a coding agent, such as Claude Code or Cursor, read the
databases you allow, over the Model Context Protocol. An agent has three
tools: list the connections, describe a schema, run a query.

What I wanted from it: an agent never sees where a database is or what
opens it. Not the host, not the password, not the SSH key. The crate that
speaks MCP, `crates/tabletist-mcp`, cannot name any of that. It gets a
`Gateway`:

[crates/tabletist-mcp/src/gateway.rs, lines 61 to 86](https://github.com/igor-alexandrov/tabletist/blob/2294c3d1e8b65efedaa32b872720c4cea65a2cae/crates/tabletist-mcp/src/gateway.rs#L61-L86)

```rust
/// Whoever holds the connections agents may use.
///
/// A connection whose access is Off is not among [`Gateway::connections`]
/// and cannot be opened: to the server it does not exist.
pub trait Gateway: Send + Sync + 'static {
    type Session: Session;

    /// The connections agents may use, as they are now.
    fn connections(&self) -> Vec<Listed>;

    /// The session of the connection with this id, for one call. A
    /// connection runs one call at a time: a second one waits here, and is
    /// [`Failure::Busy`] when it has waited the connection's timeout.
    /// Opening is the implementation's to bound as well: the server's own
    /// timer starts when it has the session.
    ///
    /// Once `stop` is cancelled, whatever the session is doing is ended,
    /// and the call that asked answers [`tabletist_db::Error::Cancelled`].
    /// A statement that was sent is awaited to its end all the same: the
    /// futures of a session are never dropped half way.
    fn open(
        &self,
        id: &str,
        stop: &CancellationToken,
    ) -> impl Future<Output = Result<Self::Session, Failure>> + Send;
}
```

The app implements the gateway. The MCP crate sees connection ids and
names, and a `Session` it can ask for schemas and reads. It has no type
that holds a host or a password, and the `secrets.rs` test above makes
sure it never starts naming one.

Every read is fenced twice. First a check on the text of the
statement, before anything reaches a database. Then the database itself:

[crates/tabletist-db/src/agent.rs, lines 14 to 19](https://github.com/igor-alexandrov/tabletist/blob/2294c3d1e8b65efedaa32b872720c4cea65a2cae/crates/tabletist-db/src/agent.rs#L14-L19)

```rust
//! The check is the first fence, not the only one. What passes it runs
//! through [`crate::Connection::run_agent_read`], as any read-only script
//! does ([`crate::ScriptMode::ReadOnly`]): prepared alone by the database,
//! in a read-only transaction that is rolled back. A write this check took
//! for a read is refused there. [`Limits`] is how much a read may take,
//! and [`Answer`] what it gave.
```

On PostgreSQL that means:

[crates/tabletist-db/src/pg/script.rs, lines 446 to 463](https://github.com/igor-alexandrov/tabletist/blob/2294c3d1e8b65efedaa32b872720c4cea65a2cae/crates/tabletist-db/src/pg/script.rs#L446-L463)

```rust
/// The open's steps, in order: the transaction, how it plans a cursor,
/// and for an agent's run its timeout and the views' question (a script's
/// run takes the snapshot with `SELECT 1`), and last the guard's savepoint.
fn opening_steps(sent: Option<Sent<'_>>) -> Vec<String> {
    let mut steps = vec![
        "BEGIN READ ONLY".to_owned(),
        "SET LOCAL cursor_tuple_fraction = 1".to_owned(),
    ];
    match sent {
        Some(sent) => steps.extend([
            format!("SET LOCAL statement_timeout = {}", sent.timeout_ms()),
            super::views::reaching(),
        ]),
        None => steps.push("SELECT 1".to_owned()),
    }
    steps.push("SAVEPOINT tabletist_guard".to_owned());
    steps
}
```

MySQL starts `START TRANSACTION READ ONLY`, and SQLite runs under
`query_only` with an authorizer. That authorizer is the one from the
`unsafe` section: it is half of why `tabletist-sqlite-ffi` exists.

BigQuery is the exception, and I would rather say so. It has no
transactions, so there is no read-only one to fall back on. A BigQuery
connection is read-only in the whole app, and its adapter sends only a
statement the first check proves is a read. On BigQuery that check is the
fence that holds.

What an agent sends (a statement, a value, a name) goes into a log of
calls the user can read in the app, and nowhere else. Not into the app's
own log file, and not into an error sent back over the protocol. That took
more than care in my own code: the MCP SDK, sqlparser and tokio-postgres write what a
client sent to the logs themselves, so the app's log keeps none of their
words. If `RUST_LOG` lets such a line through, it says only that the line
was there. The other test in `secrets.rs` runs a server against databases
it cannot open, sends a statement and a client name with markers in them,
and checks three things: no path reaches the agent or either log, the
markers are in the log of calls, and none of them is in a line the app
wrote.

There is more to say about this part, and a later post will cover it.

## What I'd do differently, and what's next

The rules I trust are the ones a machine checks. Two of mine still are
not, and I would fix both before a fifth engine comes in.

TextRole and focus should be tests, like `tests/keys.rs`. Both rules hold
today because I review for them. A test that reads the views for a
`FontId` or a `FontFamily`, or for a ring painted round a control, would be
the same shape as the three tests above, and I would stop having to look.

And `==` on a `Driver` should not compile at all. Today `Driver` derives
`PartialEq` because `ConnectSpec`, the saved connection that holds it,
derives it too, and tests compare drivers with `assert_eq!`. So the
engines rule leans on a test that reads text, where the type could have
said it. I would rather give up the derive, and write those comparisons
another way, than keep a rule the compiler could hold.

What egui made hard, each with its scar in the code:

- **Paste on Hyprland.** winit made one Wayland data device per seat, and
  egui-winit read the clipboard through it. Hyprland sends the selection
  only to a client's first data device, so paste never worked there. The
  fix is in [Carmine Paolino](https://github.com/crmne)'s forks of winit
  and egui. Tabletist shares them with
  [spotifast](https://github.com/crmne/spotifast), his Spotify client, along
  with his [fastframe](https://github.com/crmne/fastframe) crates for text,
  fonts, icons, themes and updates:

  [Cargo.toml, lines 185 to 192](https://github.com/igor-alexandrov/tabletist/blob/2294c3d1e8b65efedaa32b872720c4cea65a2cae/Cargo.toml#L185-L192)

  ```toml
  # crmne/winit apps-0.30, used by the eframe fork above. It moves with egui:
  # winit makes one wl_data_device per seat (for file drops), and egui-winit
  # reads and writes the clipboard through it rather than through
  # smithay-clipboard's own. Hyprland sends the selection only to a client's
  # first data device, so with two of them paste never worked there (#115).
  # The branch's tip: two macOS fixes past ed7caa90, the revision the egui
  # fork and fastframe's guide name, which this one builds on.
  winit = { git = "https://github.com/crmne/winit", rev = "0bed9dc0a7db02590a279fb8bac795fa39ee6948" }
  ```

- **Text a cell should not draw as is.** A database value can hold control
  characters and invisible Unicode format characters. egui draws none of
  them, and its bidi pass obeys the direction ones:

  [crates/tabletist-core/src/format.rs, lines 210 to 214](https://github.com/igor-alexandrov/tabletist/blob/2294c3d1e8b65efedaa32b872720c4cea65a2cae/crates/tabletist-core/src/format.rs#L210-L214)

  ```rust
  /// Whether `character` draws nothing, or changes how the text around it is
  /// drawn: controls (C0, DEL and C1) and the invisible Unicode format
  /// characters (general category Cf). egui draws none of these, and its bidi
  /// pass obeys the direction ones, so U+202E shows the text after it
  /// backwards.
  ```

  In a database client that matters: U+202E can make a value read as
  something it is not. Tabletist writes each of those characters out, as
  `<U+202E>`.

What it does not do yet: it speaks to these four engines and no others.
Binary values cannot be edited. Agents only read: they have no tool that
writes. The app is in English only.

The code is at https://github.com/igor-alexandrov/tabletist, and the site
with downloads for all three systems is https://igor.works/tabletist/. If
something breaks, or a rule above has a hole I did not list, please file
an issue.

*I built Tabletist with a lot of help from Claude Code, and it helped me
check every code sample in this post against the repository. The words
and the decisions are mine.*
