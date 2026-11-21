# Performance & Benchmarks

## Reproducible Benchmarks

Run the included benchmark script in `mongory-rb` to measure `Mongory::Matcher` on your local Ruby runtime:

```bash
ruby script/bench.rb
```

### Measured Results (Apple M3, macOS arm64, Ruby `4.0.5`, 100,000 records)

| Engine / Case | Simple (`age >= 18`) | `$or` (`age >= 18` or `status == "active"`) |
|---|---|---|
| Plain Ruby `Array#count` | `7.26 ms` (`72.6 ns/rec`) | `6.85 ms` (`68.5 ns/rec`) |
| `Mongory::Matcher` (`mongory-core` C99) | `7.67 ms` (`76.7 ns/rec`) | `12.92 ms` (`129.2 ns/rec`) |

> For cross-language benchmarks (`mongory-js`, `mongory-go`), see [Mongory Central](https://mongoryhq.github.io/mongory-central/#benchmarks).

## Optimization Tips

- **Reuse `Mongory::Matcher` Instances**: Compile once with `Mongory::Matcher.new(condition)` and call `#match?` across records to avoid recompiling the condition tree.
- **Priority Ordering & Dynamic Re-Sorting**: Mongory automatically orders cheaper equality/existence checks before regex or array scans, and re-sorts siblings if a lazy array matcher is constructed.
- **Inspect Plans**: Use `.explain` / `.trace` to verify cheap fields short-circuit early.
