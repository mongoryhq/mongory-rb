# Performance & Benchmarks

## Reproducible Benchmarks

Run the included benchmark script in `mongory-rb` to measure your local Ruby runtime (and `CMatcher` when the native C extension is built/installed):

```bash
ruby script/bench.rb
```

### Measured Results (Apple M3, macOS arm64)

#### Ruby (`mongory-rb`, 100,000 records, Ruby `4.0.5`)

| Engine / Case | Simple (`age >= 18`) | `$or` (`age >= 18` or `status == "active"`) |
|---------------|----------------------|---------------------------------------------|
| Plain Ruby `Array#count` | `6.28 ms` (`62.8 ns/rec`) | `7.11 ms` (`71.1 ns/rec`) |
| Pure Ruby `QueryMatcher` | `34.51 ms` (`345.1 ns/rec`) | `52.60 ms` (`526.0 ns/rec`) |
| C Extension `CMatcher` | Run `bundle exec rake compile && bundle exec ruby script/bench.rb` on a compiled environment | — |

#### Cross-Language Engines (Apple M3, 10,000 records)

- **`mongory-js` (Node `v23.1.0`, `npm run bench`)**: `simple` `18.7 ns/rec`, `$or` `43.0 ns/rec`, `nested_and` `54.6 ns/rec`, `in_array_field` `39.0 ns/rec`, `large_in_500` `41.9 ns/rec`, `regex` `39.7 ns/rec`.
- **`mongory-go` (Go `bench_test.go`, `0 B/op`, `0 allocs/op` on maps)**: `simple` `25.12 ns/rec`, `$or` `39.86 ns/rec`, `nested_and` `42.52 ns/rec`, `in_array_field` `45.20 ns/rec`, `regex` `44.37 ns/rec`.

## Optimization Tips

- **Priority Ordering & Dynamic Re-Sorting**: Mongory automatically orders cheaper equality/existence checks before regex or array scans, and re-sorts siblings if a lazy array matcher is constructed.
- **Inspect Plans**: Use `.explain` / `.trace` to verify cheap fields short-circuit early.
- **Native C Acceleration**: Enable `.c` per query or `Mongory.enable_c_extension_by_default!` when `CMatcher` is available for CPU-bound filters.
