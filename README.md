# Movie search (TMDB)

Search films by title and open a details screen, with results cached offline
and a deep link straight to a film. Task description: [`TZ.md`](TZ.md).

- Search from 2 characters, debounced, results as poster / title / description
- Details screen: poster, title, description, rating
- Results cached in sqflite and served when the network is unavailable — and
  said to be cached, rather than passed off as current
- Deep link `privattest://movie/<id>`, working from a cold start

## Getting started

Requires Flutter `>= 3.45.0` (developed on 3.47.0 / Dart 3.13).

```bash
cp assets/env/app.env.example assets/env/app.env   # then paste your TMDB v3 key
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

Get a key at https://www.themoviedb.org/settings/api. Without it the app opens
on a screen explaining that, rather than failing every request with a 401.

Generated sources (`*.freezed.dart`, `*.g.dart`, `injection.config.dart`) are
git-ignored, so `build_runner` must run once after checkout.

## Deep links

```bash
# Android
adb shell am start -a android.intent.action.VIEW \
  -d "privattest://movie/436270" com.example.privat_test

# iOS simulator
xcrun simctl openurl booted "privattest://movie/436270"
```

Works from a cold start: the details screen loads by id rather than relying on
state handed over by the list.

Android builds the initial route from `Uri.getPath()` alone, dropping the URI
authority, so the link above arrives as `/436270`. The router rewrites a bare
numeric path to `/movie/<id>`, which makes both that form and
`privattest:///movie/436270` land on the same screen on every platform. Ids are
bounded to ten digits, because on the web `int` is a JS double and an overlong
id would round to a different film rather than fail to parse.

## Architecture

Clean Architecture, feature-first. `presentation → domain ← data`; `domain/`
imports neither Flutter nor any transport or storage package.

```
lib/
├── app/            composition root — DI, router, theme
├── core/           config, errors, Result, Dio setup, sqflite schema, routes
└── features/movies/
    ├── domain/         entities, repository abstraction, use cases
    ├── data/           retrofit + sqflite data sources, models, repository impl
    └── presentation/   blocs, pages, widgets
```

**Caching.** `MovieRepositoryImpl` is remote-first: it calls TMDB, stores the
response, and reads sqflite only when the call fails — then flags the results so
the UI says they are cached. Queries are normalised to lower case so
`Black Adam` and `black adam` share one entry.

Three tables: `movies` stores each film once, `search_results` maps a query to
its movie ids **and their order**, and `searched_queries` records that a query
ran at all — without it, a search that legitimately matched nothing is
indistinguishable offline from one never made. Movies are written with an
`ON CONFLICT DO UPDATE` upsert, never `ConflictAlgorithm.replace`: SQLite
implements REPLACE as DELETE + INSERT, and with foreign keys enabled that delete
cascades, evicting the film from every cached search.

**Errors.** Data sources throw; repositories translate into a sealed `Failure`
and return `Result<T>`. Which failures may be answered from cache is one
decision in `isRecoverableFromCache`: network and server errors, yes; an
invalid key, a failed TLS handshake, a cancelled request or an unexpected error,
no — those must not be hidden behind stale data.

**Search.** All events share one `restartable()` pipeline with the 300 ms
debounce inside the handler, so clearing the field calls off a query still
waiting to fire as well as one already in flight.

## Packages beyond the required stack

The task asks that additional frameworks be justified. Required by the spec:
`bloc`, `retrofit`/`dio`, `sqflite`.

| Package | Why |
| --- | --- |
| `freezed` + `json_serializable` + `build_runner` | Immutable entities and models with value equality, and sealed unions for bloc states and failures — the analyzer then proves every state is handled |
| `get_it` + `injectable` | Wires the layers so `domain` never reaches for a concrete implementation; annotations keep the graph in one generated file |
| `go_router` | Declarative routes and built-in platform deep-link handling, so no bespoke platform channel |
| `flutter_dotenv` | Keeps the TMDB key out of source control |
| `bloc_concurrency` | `restartable()` — a newer query cancels the in-flight one |
| `cached_network_image` | Disk-caches posters, so re-scrolling and offline views don't refetch |
| `mocktail` + `bloc_test` + `sqflite_common_ffi` | Test doubles, bloc assertions, and a real in-memory sqlite for data-source tests |

No `dartz`/`fpdart`: `Result<T>` and `Failure` are hand-written sealed classes,
and Dart 3 pattern matching gives the same exhaustiveness without the dependency.

`freezed` resolves to `4.0.0-dev.3` — the only release compatible with
`analyzer` 13 / Dart 3.13, which `build_runner` 2.16 requires. It pins
`freezed_annotation` to exactly 3.1.0, and its class syntax is identical to
stable 3.x.

## Scope

Search returns TMDB's first page. Paging is not in the task, so rather than
build it, the list says when it is showing part of the answer
("Showing the first 20 of 340 matches") instead of silently truncating.

## Tests

```bash
flutter test
```

71 tests covering the use case's minimum-length rule, the repository's cache
fallback and failure translation, the local data source against real sqlite
(ordering, per-query isolation, the cascade-delete regression), the v1→v2
migration and its backfill, both blocs including debounce and cancellation, both
screens, and deep-link route resolution.
