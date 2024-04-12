#!/usr/bin/env bash

set -ex

if [[ "${target_platform}" == "linux-64" ]]; then
  # similar to settings upstream in polars
  export RUSTFLAGS='-C target-feature=+fxsr,+sse,+sse2,+sse3,+ssse3,+sse4.1,+sse4.2,+popcnt,+avx,+fma'
fi

echo rustc --version

# if [[ "${build_platform}" == "linux-64" ]]; then
#   # we need to add the generate-import-lib feature since otherwise
#   # maturin will expect libpython DSOs at PYO3_CROSS_LIB_DIR
#   # which we don't have since we are not able to add python as a host dependency
#   cargo add pyo3 \
#       --manifest-path py-polars/Cargo.toml \
#       --features "abi3-py38,extension-module,multiple-pymethods,generate-import-lib"
#   maturin build --release --strip
#   pip install target/wheels/polars*.whl --target $PREFIX/lib/site-packages --platform linux_x86_64 --no-deps --no-build-isolation
# else
#   # Run the maturin build via pip which works for direct and
#   # cross-compiled builds.
#   $PYTHON -m pip install . -vv --no-deps --no-build-isolation --ignore-installed --no-cache-dir
# fi
$PYTHON -m pip install . -vv --no-deps --no-build-isolation --ignore-installed --no-cache-dir

# The root level Cargo.toml is part of an incomplete workspace
# we need to use the manifest inside the py-polars
cd py-polars
cargo-bundle-licenses --format yaml --output ../THIRDPARTY.yml