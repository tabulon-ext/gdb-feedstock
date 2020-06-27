#!/usr/bin/env bash -ex

# This test tries to simulate a crash on a python process. The process under test
# forces a crash by emitting a SIGSEGV signal to itself. This is similar to what
# would happen on a python code calling a C/C++ module which causes a seg fault.
# When that happens we should be able to use the python extensions for gdb to get
# a nicer stack trace (instead of getting cryptic frames with CPython internals).
#
# To test that, we just run the process using gdb, let it crash and try to use the
# py-bt command to print the Python stack trace. This command is provided by CPython
# repository.
#
# You can find more about it:
#
# - https://github.com/python/cpython/blob/master/Tools/gdb/libpython.py
# - https://devguide.python.org/gdb

echo "CONDA_PY:$CONDA_PY"
export CONDA_PY=`python -c "import sys;print('%s%s'%sys.version_info[:2])"`
echo "CONDA_PY:$CONDA_PY"

gdb -batch -ex "run" -ex "py-bt" --args python "$RECIPE_DIR/testing/process_to_debug.py" | tee gdb_output
if [[ "$CONDA_PY" != "27" ]]; then
    grep "built-in method kill" gdb_output
fi

# Unfortunately some python packages do not have enough debug info for py-bt
#
# This happens because conda-forge only provides packages with all optimizations enabled.
# Depending on Python's and gdb version, the debug info present on those binaries are not
# enough to for the libpython.py extension. If the Python version one wants to debug falls
# into this list, they would have to rebuild the python package locally tweaking -O and -g
# flags in Python recipe build script.
#
# This list is mostly for documentation purposes, so we know exactly which versions can be
# debugged out-of-the-box with this gdb package. When things change, there is not much to be
# done besides adding or removing versions from this list.
insufficient_debug_info_versions=("27" "36")

if [[ " ${insufficient_debug_info_versions[@]} " =~ " ${CONDA_PY} " ]]; then
    if grep "line 3" gdb_output; then
        echo "This test was expected to fail due to missing debug info in python"
        echo "As it passed the test should be re-enabled"
        exit 1
    fi
else
    # We are lucky! This Python version has enough debug info for us to easily identify
    # the exact Python code where the crash happened.
    grep "line 3" gdb_output
    grep "process_to_debug.py" gdb_output
    grep 'os.kill(os.getpid(), signal.SIGSEGV)' gdb_output
fi

grep "Program received signal SIGSEGV" gdb_output