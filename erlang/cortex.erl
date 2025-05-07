-module(cortex).
-export([sync/4]).

%% Mock function for the tests
sync(_CortexPid, _ActuatorPid, _Fitness, _HaltFlag) ->
    ok.