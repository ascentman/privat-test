# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Code generation

Generated sources (`*.freezed.dart`, `*.g.dart`, `lib/app/di/injection.config.dart`)
are **git-ignored and never hand-edited**. After changing any annotated class,
adding a dependency, or a fresh checkout:

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

`flutter analyze` fails on a clean checkout until that command has run.

## Architecture

Clean Architecture, feature-first. Everything for a feature lives under
`lib/features/<feature>/{domain,data,presentation}`; `lib/core/` holds only
cross-feature primitives and `lib/app/` the composition root (DI, router, theme).

The dependency rule is `presentation → domain ← data`:

- `domain/` must not import Dio, sqflite, Flutter or any data-layer type.
  It holds entities, repository abstractions and use cases.
- `data/` implements the domain abstractions. Models (`MovieModel`) own the JSON
  and sqflite shapes and convert at the boundary via `toEntity()`; entities never
  leave the repository as models.
- `presentation/` talks to use cases only, through blocs.

Business rules belong in use cases, not widgets — e.g. the 2-character minimum
query length lives in `SearchMovies`, so it holds for every caller.

Shared routing constants live in `lib/core/router/app_routes.dart`, not beside
the router: `app_router.dart` imports the feature pages, so a page importing it
back would close a cycle. Build every movie route with `AppRoutes.movie(id)` and
parse every incoming one with `AppRoutes.parseMovieId`, which enforces the
length bound described under **Deep links**.

## Conventions

- **freezed**: data classes are `abstract class X with _$X`; unions are
  `sealed class X with _$X`. The pre-3.x plain `class X with _$X` no longer
  compiles. Add `const X._();` when the class defines getters or methods.
- **Errors**: data sources throw (`CacheException`, `DioException`); repositories
  translate them into a `Failure` and return `Result<T>`. Nothing above the data
  layer sees a transport exception, and both repository methods end in a
  catch-all, because deserialisation happens after Dio returns and throws a
  plain `TypeError`.
- **What may be answered from cache** is one decision, in
  `isRecoverableFromCache`: network and server failures only. Auth, TLS,
  cancellation and unexpected failures must not be papered over with stale data.
  Adding a `Failure` variant means deciding its side of that line.
- **DI**: annotate with `@injectable` / `@LazySingleton(as: Abstraction)`, or add
  a `@module` getter for third-party types that cannot be annotated. Regenerate
  after every change. Retrofit clients need a module because their generated
  implementation comes from a factory constructor.
- **BLoC**: one bloc per screen; events and states are freezed unions in
  `part` files next to the bloc. Events that **replace** what is on screen go
  through one handler on the event supertype with `restartable()`, not one
  handler per type — cancellation does not cross pipelines, so separate
  handlers cannot call each other off. Events that **append** (paging) need
  their own `droppable()` pipeline instead, and must check that what they
  fetched still belongs on screen before emitting, since nothing cancels them.
  `restartable()` silences a superseded handler's emits but does not stop its
  body, so check `emit.isDone` after every `await` before touching state.
- Lints are stricter than `flutter_lints` defaults: single quotes, trailing
  commas, explicit return types, `prefer_final_locals`.

## Configuration

The TMDB API key is read from the git-ignored `assets/env/app.env`
(see `app.env.example` beside it). The pubspec declares the **directory**, not
the file: declaring the file makes a checkout without a key fail asset
resolution at build time instead of reaching `AppConfig.hasApiKey`, which exists
to explain the problem on screen. Never hardcode the key or commit `app.env`.

Anything that logs a request URL must go through `redactApiKey` — the key
travels as a query parameter.

## Cache

`movies` stores each film once; `search_results` maps a query to its movie ids
and their order; `searched_queries` records that a query ran at all, plus the
total the API reported.

- Write movies with the `ON CONFLICT DO UPDATE` upsert in
  `_upsertMovie`, never `ConflictAlgorithm.replace`: SQLite implements REPLACE
  as DELETE + INSERT, and with foreign keys on, that delete cascades and drops
  the film from every cached search.
- `getCachedSearch` returns `null` for a query never run and an empty list for
  one that ran and matched nothing. Offline those are different answers.
- Schema changes need a matching `onUpgrade` branch **and** a backfill for data
  the old schema already held, plus a test in
  `test/core/database/app_database_migration_test.dart`, which opens a real
  database at the previous version.

## Testing

```bash
flutter test
```

Data-source tests run against real in-memory sqlite via `sqflite_common_ffi`
(`sqfliteFfiInit()` + `databaseFactoryFfi` in `setUpAll`) rather than mocking the
database, so the schema and the ordering join are exercised for real.
Bloc tests must `wait` past the 300 ms search debounce.

When fixing a bug, check the new test fails against the old code before keeping
it — several tests here pass for reasons unrelated to what they claim.

## Deep links

Scheme `privattest://movie/<id>`, handled by go_router.

Android builds the initial route from `Uri.getPath()` alone, so the URI's
authority is dropped and `privattest://movie/436270` reaches the app as
`/436270`. `app_router.dart` compensates with a redirect that rewrites a bare
numeric path to `/movie/<id>`.

Ids are bounded to ten digits, which keeps the guard from depending on how a
platform parses an overlong number: the VM rejects it, a JS double would round
it to a different, possibly real, film. Keep the bound if web is ever added
back.

Keep the details screen loading by id: a cold-start deep link has no movie
handed over by the list, which is why the screen must survive on what it fetches
and on `DetailsFailure.movie`.
