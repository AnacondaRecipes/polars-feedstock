#!/usr/bin/env bash

set -euox pipefail

$PYTHON -m pip install . -vv --no-deps --no-build-isolation
