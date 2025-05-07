# Erlang to Elixir Conversion Guide for Bardo

This document provides guidance on converting the remaining Erlang modules in the original codebase to Elixir.

## General Conversion Rules

1. Follow the module mapping in `module_mapping.md`
2. Convert Erlang records to Elixir maps or structs
3. Use Elixir's pattern matching instead of Erlang's `case` expressions where possible
4. Use the `Bardo.Logger` module instead of direct `io:format` calls
5. Use Elixir's pipelines (` < /dev/null | >`) for cleaner function composition
6. Convert Erlang-style process messaging to Elixir's GenServer calls where appropriate

## Naming Conventions

- Erlang atoms (`:atom`) become Elixir atoms (`:atom`)
- Erlang variables (`Variable`) become Elixir variables (`variable`)
- Erlang functions (`function_name`) become Elixir functions (`function_name`)
- Erlang modules (`module_name`) become Elixir modules (`Bardo.ModuleName`)

## Data Structure Conversions

### Erlang Record to Elixir Struct

Erlang:
```erlang
-record(neuron, {
  id,
  generation,
  cx_id,
  af,
  pf,
  aggr_f
}).
```

Elixir:
```elixir
defmodule Bardo.AgentManager.Neuron.State do
  defstruct [
    :id,
    :generation, 
    :cx_id,
    :af,
    :pf,
    :aggr_f
  ]
end
```

### Function Conversion Example

Erlang:
```erlang
-spec function_name(Args) -> Result.
function_name(Args) ->
  case X of
    A ->
      do_something();
    B ->
      do_something_else()
  end.
```

Elixir:
```elixir
@spec function_name(args) :: result
def function_name(args) do
  case x do
    a -> 
      do_something()
    b -> 
      do_something_else()
  end
end

# Or better, with pattern matching:
@spec function_name(args) :: result
def function_name(args) when x == a do
  do_something()
end

def function_name(args) when x == b do
  do_something_else()
end
```

## Testing

For each converted module, create corresponding ExUnit tests in the `test/` directory following the pattern in existing tests.

## Important Notes

1. When converting functions like `init/1`, `handle_call/3`, etc., make sure to add the `@impl true` annotation
2. For Erlang process-oriented code, use Elixir's GenServer, Agent, Task, or Supervisor as appropriate
3. Preserve the original functionality while making the code more idiomatic Elixir
4. Add `@moduledoc` and `@doc` where appropriate to improve documentation

## Priority Order

1. Finish the core agent_mgr modules (neuron.erl, cortex.erl, etc.)
2. Convert population_mgr modules
3. Convert experiment_mgr modules
4. Convert scape_mgr modules
5. Convert example applications and benchmarks
