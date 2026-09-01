# Vendored Apache Arrow.jl code

The files `ArrowCore.jl` and `ArrowStrings.jl` in this directory are vendored,
unmodified, from https://github.com/apache/arrow-julia, branch `core-rewrite`
(the Arrow.jl 3.0 rewrite), commit
`987869984c30af99d6af3cc4dbac3c073749b0da` (retrieved 2026-08-31):

- `ArrowCore.jl` ← `src/ArrowCore.jl`
- `ArrowStrings.jl` ← `src/ArrowStrings/src/ArrowStrings.jl`

They are licensed under the Apache License, Version 2.0 (see
`LICENSE-APACHE.md` in this directory, and the accompanying `NOTICE` file),
not under the MIT license that covers the rest of this repository.

This vendoring is temporary: once upstream registers these modules as
standalone packages, the files here will be deleted and replaced by ordinary
package dependencies. Do not edit these files locally — change upstream and
re-vendor instead.
