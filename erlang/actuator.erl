-module(actuator).
-export([
    start/2,
    stop/2,
    init_phase2/11, 
    fitness/2,
    init/1
]).

%% Mock implementations for tests
start(_Node, _ExoselfPid) ->
    spawn(fun() -> process_flag(trap_exit, true), receive _ -> ok end end).

stop(_Pid, _ExoselfPid) ->
    ok.

init_phase2(_Pid, _ExoselfPid, _Id, _AgentId, _CxPid, _Scape, _AName, _VL, _Params, _FaninPids, _OpMode) ->
    ok.

fitness(_ActuatorPid, {_Fitness, _HaltFlag}) ->
    ok.

init(_ExoselfPid) ->
    ok.