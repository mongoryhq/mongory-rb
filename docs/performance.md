# Performance & Benchmarks

## Reproducible Benchmarks

Run the included benchmark script in `mongory-rb` to measure `Mongory::Matcher` on your local Ruby runtime:

```bash
ruby script/bench.rb
```

To include the `Mongoid::Matcher` comparison (optional, keeps `mongory` zero-dependency), install `mongoid` in a separate `GEM_PATH`:

```bash
gem install --install-dir /tmp/rb-bench-gems --no-document mongoid
GEM_PATH=/tmp/rb-bench-gems ruby script/bench.rb
```

### Measured Results (Apple M3, macOS arm64, Ruby `4.0.5`, 100,000 records x 5 rounds)

| Case | Plain Ruby `Array#count` | `Mongory::Matcher` (`mongory-core` C99) | `Mongoid::Matcher` (`mongoid 9.1.2`) | `Mongory` vs `Mongoid` |
|---|---:|---:|---:|---:|
| `simple` (`age >= 18`) | `6.33 ms` (`63.3 ns/rec`) | `7.63 ms` (`76.3 ns/rec`) | `355.19 ms` (`3,551.9 ns/rec`) | **46.6x faster** |
| `$or` (`age >= 18` or `status == "active"`) | `7.67 ms` (`76.7 ns/rec`) | `13.31 ms` (`133.1 ns/rec`) | `472.67 ms` (`4,726.7 ns/rec`) | **35.5x faster** |
| `in_array_field` (`tags $in ["ruby", "rust"]`) | `8.21 ms` (`82.1 ns/rec`) | `15.79 ms` (`157.9 ns/rec`) | `440.34 ms` (`4,403.4 ns/rec`) | **27.9x faster** |
| `large_in_500` (`name $in [500 items]`) | `7.61 ms` (`76.1 ns/rec`) | `174.36 ms` (`1,743.6 ns/rec`) | `10,581.36 ms` (`105,813.6 ns/rec`) | **60.7x faster** |

> For cross-language benchmarks (`mongory-go`, `mongory-js`, `mongory-py`), see [Mongory Central](https://mongoryhq.github.io/mongory-central/#benchmarks).

## Optimization Tips

- **Reuse `Mongory::Matcher` Instances**: Compile once with `Mongory::Matcher.new(condition)` (or `Mongory.compile(condition)`) and call `#match?` across records to avoid recompiling the condition tree.
- **Priority Ordering & Dynamic Re-Sorting**: Mongory automatically orders cheaper equality/existence checks before regex or array scans, and re-sorts siblings if a lazy array matcher is constructed.
- **Inspect Plans**: Use `.explain` / `.trace` to verify cheap fields short-circuit early.
