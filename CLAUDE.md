# Claude Integration Notes

This file contains notes about integrating this project with Claude and important commands to run.

## Testing Commands

To run all tests:
```
mix test
```

To run tests with tags:
```
mix test --only parameterized
mix test --exclude integration
```

## Common Issues

### Test Failures

Several test failures stem from:

1. Morphology issues with handling sensor and actuator lookups - fixed by using `Map.get/3` for safe access
2. Incorrect assertions in parameterized tests - fixed with more flexible assertions
3. Type specification issues - fixed by using proper return types

### Common Error Patterns

- Erlang error with `{:already_started, #PID<X.XXX.X>}` - mock state is persisting between tests
- `{:error, :noproc}` - processes not started or terminated unexpectedly 
- `{:error, :not_found}` - resources (like experiments, populations) missing

## Linting Commands

To run the linters:
```
mix compile --warnings-as-errors
mix credo
mix dialyzer
```

## Cleanup Commands

To clean up temporary files and restart:
```
mix clean
rm -rf _build
mix deps.get
```