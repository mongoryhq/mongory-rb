# Performance & Benchmarks

## Reproducible Benchmarks

Run the included benchmark script in `mongory-rb` to measure your local Ruby runtime (and `CMatcher` when the native C extension is built/installed):

```bash
ruby script/bench.rb
```

### Measured Results (Apple M3, macOS arm64, Ruby `4.0.5`, 100,000 records)

| Engine / Case | Simple (`age >= 18`) | `$or` (`age >= 18` or `status == "active"`) |
|---|---|---|
| Plain Ruby `Array#count` | `7.26 ms` (`72.6 ns/rec`) | `6.85 ms` (`68.5 ns/rec`) |
| Pure Ruby `QueryMatcher` | `35.08 ms` (`350.8 ns/rec`) | `50.98 ms` (`509.8 ns/rec`) |
| C Extension `CMatcher` | `7.67 ms` (`76.7 ns/rec`, ~4.6x vs Pure Ruby) | `12.92 ms` (`129.2 ns/rec`, ~3.9x vs Pure Ruby) |

> For cross-language benchmarks (`mongory-js`, `mongory-go`), see [Mongory Central](https://mongoryhq.github.io/mongory-central/#benchmarks).

## Optimization Tips

- **Native C Acceleration**: Enable `.c` per query (`records.mongory.c.where(...)`) or `Mongory.enable_c_extension_by_default!` when `CMatcher` is available for ~4–5x faster evaluation (near native Ruby block speed).
- **Priority Ordering & Dynamic Re-Sorting**: Mongory automatically orders cheaper equality/existence checks before regex or array scans, and re-sorts siblings if a lazy array matcher is constructed.
- **Inspect Plans**: Use `.explain` / `.trace` to verify cheap fields short-circuit early.
