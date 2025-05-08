defmodule Bardo.TestSupport.MockExamples do
  @moduledoc """
  Examples demonstrating how to use the EnhancedMock system.
  
  This module provides practical examples of how to use the various features
  of the EnhancedMock system to test different aspects of the Bardo library.
  """
  
  import ExUnit.Assertions
  alias Bardo.TestSupport.EnhancedMock
  alias Bardo.AgentManager.{Cortex, Neuron, Sensor, Actuator}
  alias Bardo.PopulationManager.{Genotype, GenomeMutator}
  
  @doc """
  Example: Testing with simple function mocking
  
  This example shows how to mock a simple function with expected return values.
  """
  def example_simple_mocking do
    # Create a mock for the Cortex module
    EnhancedMock.mock(Cortex)
    
    # Set an expectation for the activate function
    EnhancedMock.expect(Cortex, :activate, fn(_nn, inputs) -> 
      # Return a fixed output regardless of inputs
      [0.5]
    end)
    
    # Now when code calls Cortex.activate, it will return [0.5]
    # For example:
    nn = %{state: :ready}  # Mock neural network
    result = Cortex.activate(nn, [0.0, 1.0])
    
    # Verify result
    assert result == [0.5]
    
    # Verify expectations were met
    EnhancedMock.verify!()
  end
  
  @doc """
  Example: Testing with call counting
  
  This example shows how to verify that functions are called a specific number of times.
  """
  def example_call_counting do
    # Create a mock for the Cortex module
    EnhancedMock.mock(Cortex)
    
    # Set an expectation that activate should be called exactly twice
    EnhancedMock.expect(Cortex, :activate, fn(_nn, _inputs) -> 
      [0.5]
    end, count: 2)
    
    # Make some calls
    nn = %{state: :ready}
    Cortex.activate(nn, [0.0, 1.0])
    Cortex.activate(nn, [1.0, 0.0])
    
    # This would fail verification:
    # Cortex.activate(nn, [1.0, 1.0])
    
    # Verify expectations were met
    EnhancedMock.verify!()
  end
  
  @doc """
  Example: Testing with argument validation
  
  This example shows how to verify that functions are called with specific arguments.
  """
  def example_argument_validation do
    # Create a mock for the Neuron module
    EnhancedMock.mock(Neuron)
    
    # Set an expectation with specific argument values
    EnhancedMock.expect(Neuron, :forward, fn(neuron_pid, input_pid, input) -> 
      :ok
    end, args: [self(), self(), [1.0]])
    
    # Make a call with the expected arguments
    Neuron.forward(self(), self(), [1.0])
    
    # This would fail verification:
    # Neuron.forward(self(), self(), [0.5])
    
    # Set an expectation with a validation function
    EnhancedMock.expect(Neuron, :forward, fn(neuron_pid, input_pid, input) -> 
      :ok
    end, args: fn(_pid1, _pid2, input) -> 
      # Validate that input is a list of numbers between 0 and 1
      is_list(input) and Enum.all?(input, &(is_number(&1) and &1 >= 0 and &1 <= 1))
    end)
    
    # Make a call with valid arguments
    Neuron.forward(self(), self(), [0.5, 0.7])
    
    # This would fail verification:
    # Neuron.forward(self(), self(), [1.5])
    
    # Verify expectations were met
    EnhancedMock.verify!()
  end
  
  @doc """
  Example: Testing with a stateful mock
  
  This example shows how to create a mock that maintains state between calls.
  """
  def example_stateful_mock do
    # Create a stateful mock for the DB module
    initial_state = %{data: %{}}
    
    EnhancedMock.stateful_mock(Bardo.DB, initial_state, %{
      write: fn(id, record, type, state) -> 
        # Update state with the new record
        new_data = Map.put(state.data, {type, id}, record)
        new_state = %{state | data: new_data}
        {:ok, new_state}
      end,
      
      read: fn(id, type, state) ->
        # Retrieve record from state
        record = Map.get(state.data, {type, id})
        result = if record, do: record, else: :not_found
        {result, state}
      end,
      
      delete: fn(id, type, state) ->
        # Remove record from state
        new_data = Map.delete(state.data, {type, id})
        new_state = %{state | data: new_data}
        {:ok, new_state}
      end
    })
    
    # Use the DB mock
    Bardo.DB.write(:obj_1, %{name: "Test"}, :object)
    
    # Read should return the written value
    result = Bardo.DB.read(:obj_1, :object)
    assert result == %{name: "Test"}
    
    # Delete the object
    Bardo.DB.delete(:obj_1, :object)
    
    # Read should now return :not_found
    result = Bardo.DB.read(:obj_1, :object)
    assert result == :not_found
    
    # Verify final state
    state = EnhancedMock.get_state(Bardo.DB)
    assert state.data == %{}
  end
  
  @doc """
  Example: Testing a behavioral interface
  
  This example shows how to mock a behavior with multiple callbacks.
  """
  def example_behavior_mock do
    # Define a sample behavior
    defmodule SampleBehavior do
      @callback init(any()) :: {:ok, any()}
      @callback handle_call(any(), any(), any()) :: {:reply, any(), any()}
      @callback handle_cast(any(), any()) :: {:noreply, any()}
      @callback terminate(any(), any()) :: :ok
      
      def behaviour_info(:callbacks) do
        [
          {:init, 1},
          {:handle_call, 3},
          {:handle_cast, 2},
          {:terminate, 2}
        ]
      end
    end
    
    # Create a mock implementing the behavior
    EnhancedMock.mock_behavior(SampleBehavior, SampleBehavior, %{
      init: fn(args) -> 
        {:ok, args}
      end,
      
      handle_call: fn(request, from, state) ->
        case request do
          :get_state -> {:reply, state, state}
          {:set_state, new_state} -> {:reply, :ok, new_state}
          _ -> {:reply, :unknown_request, state}
        end
      end,
      
      handle_cast: fn(request, state) ->
        case request do
          {:update, value} -> {:noreply, state + value}
          _ -> {:noreply, state}
        end
      end,
      
      terminate: fn(_reason, _state) ->
        :ok
      end
    })
    
    # Call the mocked behavior functions
    {:ok, state} = SampleBehavior.init(10)
    assert state == 10
    
    {:reply, value, state} = SampleBehavior.handle_call(:get_state, :from, state)
    assert value == 10
    assert state == 10
    
    {:reply, :ok, state} = SampleBehavior.handle_call({:set_state, 20}, :from, state)
    assert state == 20
    
    {:noreply, state} = SampleBehavior.handle_cast({:update, 5}, state)
    assert state == 25
    
    # Verify expectations
    EnhancedMock.verify!()
  end
  
  @doc """
  Example: Testing with a spy
  
  This example shows how to spy on a module to record calls without changing behavior.
  """
  def example_spy do
    # Create a spy for a module
    EnhancedMock.spy(Bardo.Functions)
    
    # Use the module normally
    Bardo.Functions.sigmoid(0.5)
    Bardo.Functions.scale(0.5, 0.0, 1.0)
    
    # Check what was called
    calls = EnhancedMock.get_calls(Bardo.Functions)
    
    sigmoid_calls = Enum.filter(calls, fn {func, _args} -> func == :sigmoid end)
    assert length(sigmoid_calls) == 1
    {_, sigmoid_args} = hd(sigmoid_calls)
    assert hd(sigmoid_args) == 0.5
    
    scale_calls = Enum.filter(calls, fn {func, _args} -> func == :scale end)
    assert length(scale_calls) == 1
    {_, scale_args} = hd(scale_calls)
    assert scale_args == [0.5, 0.0, 1.0]
  end
  
  @doc """
  Example: Testing a complex interaction between components
  
  This example shows how to mock multiple components to test their interactions.
  """
  def example_complex_interaction do
    # Mock multiple components
    EnhancedMock.mock(Sensor)
    EnhancedMock.mock(Neuron)
    EnhancedMock.mock(Actuator)
    EnhancedMock.mock(Cortex)
    
    # Set up initial expectations
    
    # Sensor should perceive the environment and forward to neurons
    EnhancedMock.expect(Sensor, :percept, fn(sensor_pid, percept) ->
      # Forward perception to all neurons in fanout
      Neuron.forward(self(), sensor_pid, percept)
      :ok
    end)
    
    # Neuron forwards signals to connected neurons and actuators
    EnhancedMock.expect(Neuron, :forward, fn(neuron_pid, from_pid, input) ->
      # Process input and forward to actuator
      output = Enum.map(input, fn x -> :math.tanh(x) end)
      Actuator.forward(self(), neuron_pid, output)
      :ok
    end)
    
    # Actuator processes outputs and provides feedback
    EnhancedMock.expect(Actuator, :forward, fn(actuator_pid, from_pid, output) ->
      # Process output and send fitness to cortex
      fitness = Enum.sum(output)
      Cortex.sync(self(), actuator_pid, [fitness], 0)
      :ok
    end)
    
    # Cortex collects fitness and tells sensors to continue
    EnhancedMock.expect(Cortex, :sync, fn(cortex_pid, actuator_pid, fitness, e_flag) ->
      # When all actuators have reported, tell sensors to continue
      Sensor.percept(self(), [1.0, 0.0])
      :ok
    end)
    
    # Simulate a sensing cycle
    Sensor.percept(self(), [0.5, 0.5])
    
    # Verify the entire chain of calls
    calls = EnhancedMock.get_calls(Sensor) ++
            EnhancedMock.get_calls(Neuron) ++
            EnhancedMock.get_calls(Actuator) ++
            EnhancedMock.get_calls(Cortex)
    
    # Verify the chain of calls is correct and complete
    assert length(calls) == 4
    
    # Verify expectations were met
    EnhancedMock.verify!()
  end
end