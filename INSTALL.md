# INSTALLATION INSTRUCTIONS

nascTime can be built on any platform supported by the Simu5G and INET frameworks.

## Prerequisites

You should have:

* a working OMNeT++ v6.4.0 (or later) installation. (Download from http://omnetpp.org)
* a working INET Framework (v4.6.0) installation. (Download from http://inet.omnetpp.org)
* a working Simu5G (v1.5.0) installation, built against the above INET version. (Download from http://simu5g.org)

Make sure your OMNeT++ installation works OK (e.g. try running the samples) and is on your `PATH` (to test, try the command `which nedtool`). Confirm Simu5G's own examples run correctly before continuing — this rules out most environment issues before adding nascTime on top.

## Installing nascTime using opp_env (recommended)

`opp_env` is the supported way to set up a working nascTime environment — it installs and pins the exact OMNeT++/INET/Simu5G versions nascTime is developed against, avoiding version-mismatch issues.

1. Make sure [opp_env](https://github.com/omnetpp/opp_env) is correctly installed on your machine (macOS and Linux; Windows users can run it inside WSL2).
2. Create an opp_env workspace in an empty directory with `opp_env init`.
3. Install Simu5G and its dependencies (including OMNeT++ and INET) with `opp_env install simu5g-1.5.0`.
4. Clone nascTime into the same workspace directory, alongside the `inet-*`/`simu5g-*`/`omnetpp-*` directories `opp_env` created:
   ```
   git clone <nascTime repo URL> nascTime
   ```
5. Open a development shell scoped to this workspace with:
   ```
   opp_env shell
   ```
   Do this from within the workspace directory. This activates the correct OMNeT++/INET/Simu5G versions for the current shell session — **required** before building or running nascTime; a plain `. setenv` from an old or unrelated OMNeT++ installation will not work and will fail with an "opp_env shell" error from `Makefile.inc`.
6. From inside that shell, either start the IDE, or continue from the command line as described below.

## Building nascTime from the command line

1. From within an `opp_env shell` (step 5 above), change into the `nascTime` directory.
2. Type `make`. This regenerates `src/Makefile` automatically (via `make makefiles`, run as part of `make`'s dependency chain) and then builds the executable.
   * nascTime's top-level `Makefile` locates INET and Simu5G by assuming they sit as sibling directories to `nascTime` (i.e. `../inet-4.6.0`, `../simu5g-1.5.0`), matching the layout `opp_env install` creates. If your layout differs, override explicitly:
     ```
     make INET_ROOT=/path/to/inet SIMU5G_ROOT=/path/to/simu5g
     ```
3. Use `make MODE=debug` to build the debug version alongside the release build — both can coexist; make sure whichever one you actually run (via Qtenv or the command line) has been rebuilt after any source change, since only the mode you built is updated.
4. Run examples from the `simulations/demos/` (user-facing scenarios) or `tests/` (validation/regression scenarios) directories, e.g.:
   ```
   cd simulations/demos/frer_test
   ../../../src/nascTime -f frer_dualconn.ini
   ```
   (adjust the `.ini` filename to the scenario you want to run).

## Building nascTime from the IDE

1. Make sure INET and Simu5G projects are both open and correctly built in your workspace.
2. Import nascTime using `File | Import | General | Existing Projects into Workspace`. Select the workspace directory as the root, and do **not** check "Copy projects into workspace". Click Finish.
3. Right-click the nascTime project, `Properties | Project References`, and tick both `inet` and `simu5g` (or whatever their exact project names are in your workspace). Click "Apply and Close".
4. Build with Ctrl-B (`Project | Build All`).
5. To run an example from the IDE, select a simulation folder under `simulations/demos/` or `tests/`, and click Run on the toolbar.

## Cleaning up

* `make clean` — removes build outputs for the current mode.
* `make cleanall` — removes build outputs for both release and debug modes, and removes the generated `src/Makefile`.

---

Mohamed Seliem
