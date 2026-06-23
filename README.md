# F16ModelWorkshop
  
## Getting Started
  
This library was created with the Dyad Studio VS Code extension.  Your Dyad
models should be placed in the `dyad` directory and the files should be
given the `.dyad` extension.  Several such files have already been placed
in there to get you started.  The Dyad compiler will compile the Dyad models
into Julia code and place it in the `generated` folder.  Do not edit the
files in that directory or remove/rename that directory.

A complete tutorial on using Dyad Studio can be found [here](#).  But you
can run the provided example models by doing the following:

1. Run `Julia: Start REPL` from the command palette.

2. Type `]`.  This will take you to the package manager prompt.

3. At the `pkg>` prompt, type `instantiate` (this downloads all the Julia libraries
   you will need, and the very first time you do it it might take a while).

4. From the same `pkg>` prompt, type `test`.  This runs the model test harnesses to
   make sure the models are working as expected.  It may take some time, but you
   should eventually see the test summary reporting that the tests passed.

5. Use the `Backspace`/`Delete` key to return to the normal Julia REPL, it should
   look like this: `julia>`.

6. Type `using F16ModelWorkshop`.  This will load your model library.

7. Type `Scenario1OpenLoop()` to run the open-loop response of the F16 plant to a 10°
   pitch perturbation.  The first time you run it, this might take a few seconds, but
   each successive time you run it, it should be very fast.

8. To see simulation results type `using Plots` (and answer `y` if asked if you want
   to add it as a dependency).

9. To plot results of the simulation, simply type `plot(Scenario1OpenLoop())`.

10. You can plot variations on that simulation using keyword arguments.  For example,
    try `plot(Scenario1OpenLoop(stop=50))`.  Run `plot(Scenario1ClosedLoop())` to see
    the LQG-stabilized response to the same perturbation.
