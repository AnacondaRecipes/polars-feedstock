cd %PKG_NAME%

@rem Remove this wrapper once https://github.com/conda-forge/rust-activation-feedstock/pull/79 is merged
if %ERRORLEVEL% neq 0 exit 1
copy %RECIPE_DIR%\cargo-auditable-wrapper.bat %BUILD_PREFIX%\Library\bin\cargo-auditable-wrapper.bat
if %ERRORLEVEL% neq 0 exit 1
set "CARGO=cargo-auditable-wrapper.bat"

@rem The x86 SIMD -C target-feature / -Z tune-cpu flags below are invalid on
@rem aarch64 and crash rustc (STATUS_ACCESS_VIOLATION compiling rayon-core).
@rem Mirror build_runtime.sh: apply them only on x86_64.
if "%target_platform%"=="win-arm64" goto :aarch64_cfg

rem see https://github.com/pola-rs/polars/blob/main/.github/workflows/release-python.yml
set COMPAT_TUNE_CPU=
set COMPAT_FEATURES=+sse3,+ssse3,+sse4.1,+sse4.2,+popcnt,+cmpxchg16b
set COMPAT_CC_FEATURES=-msse3 -mssse3 -msse4.1 -msse4.2 -mpopcnt -mcx16

set NONCOMPAT_TUNE_CPU=skylake
set NONCOMPAT_FEATURES=+sse3,+ssse3,+sse4.1,+sse4.2,+popcnt,+cmpxchg16b,+avx,+avx2,+fma,+bmi1,+bmi2,+lzcnt,+pclmulqdq,+movbe
set NONCOMPAT_CC_FEATURES=-msse3 -mssse3 -msse4.1 -msse4.2 -mpopcnt -mcx16 -mavx -mavx2 -mfma -mbmi -mbmi2 -mlzcnt -mpclmul -mmovbe

if "%PKG_NAME%"=="polars-runtime-compat" (
    set tune_cpu=%COMPAT_TUNE_CPU%
    set features=%COMPAT_FEATURES%
    set cc_features=%COMPAT_CC_FEATURES%
) else (
    set tune_cpu=%NONCOMPAT_TUNE_CPU%
    set features=%NONCOMPAT_FEATURES%
    set cc_features=%NONCOMPAT_CC_FEATURES%
)

if "%PKG_NAME%"=="polars-runtime-compat" (
    set cfg=--cfg allocator="default"
) else (
    set cfg=
)

if "%tune_cpu%"=="" (
    set RUSTFLAGS=-C target-feature=%features% %cfg%
    set CFLAGS=%CFLAGS% %cc_features%
) else (
    set RUSTFLAGS=-C target-feature=%features% -Z tune-cpu=%tune_cpu% %cfg%
    set CFLAGS=%CFLAGS% %cc_features% -mtune=%tune_cpu%
)
goto :after_arch_cfg

:aarch64_cfg
@rem aarch64: skip the x86 SIMD / -Z tune-cpu flags (see build_runtime.sh).
@rem aws-lc-sys ships ARM64 .S assembly that cl.exe cannot assemble, which
@rem fails the link (LNK1181 on chacha-armv8.o). Its CMake builder selects the
@rem ClangCL toolset for msvc/aarch64 (cmake_builder.rs configure_windows), so
@rem clang-cl assembles the .S. Same conda pattern as snowflake-connector-python
@rem and py-rattler. Jitterentropy intrinsics/atomics don't build here either.
set "AWS_LC_SYS_CMAKE_BUILDER=1"
set "AWS_LC_SYS_NO_JITTER_ENTROPY=1"

:after_arch_cfg
maturin build --release
if %ERRORLEVEL% neq 0 exit %ERRORLEVEL%
%PYTHON% -m pip install . -vv --no-deps --no-build-isolation --find-links=target\wheels
if %ERRORLEVEL% neq 0 exit %ERRORLEVEL%

cd .\py-polars\runtime
cargo bundle-licenses --format yaml --output ..\..\THIRDPARTY.yml