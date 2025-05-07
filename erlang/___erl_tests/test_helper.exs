# Configure ExUnit
ExUnit.start(
  capture_log: true, 
  trace: false, 
  exclude: [:skip, :pending], 
  include: []
)