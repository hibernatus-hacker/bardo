#!/usr/bin/env elixir

Mix.install([
  {:finch, "~> 0.13"},
  {:jason, "~> 1.2"},
  {:castore, "~> 0.1"}
])

# Start required applications
Application.ensure_all_started(:finch)

# Start Finch
Finch.start_link(name: OandaFinch)

defmodule OandaClient do
  @base_url "https://api-fxpractice.oanda.com/v3"
  
  def get_accounts(api_key) do
    case request(api_key, :get, "/accounts") do
      {:ok, response} -> 
        IO.puts("Accounts retrieved successfully")
        {:ok, response}
      {:error, reason} -> 
        IO.puts("Failed to retrieve accounts: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  def get_account_details(api_key, account_id) do
    case request(api_key, :get, "/accounts/#{account_id}") do
      {:ok, response} -> 
        IO.puts("Account details retrieved successfully")
        {:ok, response}
      {:error, reason} -> 
        IO.puts("Failed to retrieve account details: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  def get_candles(api_key, instrument, params \\ %{}) do
    query_string = URI.encode_query(params)
    url = "/instruments/#{instrument}/candles?#{query_string}"
    
    case request(api_key, :get, url) do
      {:ok, response} -> 
        IO.puts("Candles for #{instrument} retrieved successfully")
        {:ok, response}
      {:error, reason} -> 
        IO.puts("Failed to retrieve candles for #{instrument}: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  def create_order(api_key, account_id, order_data) do
    case request(api_key, :post, "/accounts/#{account_id}/orders", order_data) do
      {:ok, response} -> 
        IO.puts("Order created successfully")
        {:ok, response}
      {:error, reason} -> 
        IO.puts("Failed to create order: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  defp request(api_key, method, path, body \\ nil) do
    url = @base_url <> path
    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"},
      {"Accept", "application/json"}
    ]
    
    request_body = if body, do: Jason.encode!(body), else: ""
    
    request = case method do
      :get -> Finch.build(method, url, headers)
      :post -> Finch.build(method, url, headers, request_body)
    end
    
    case Finch.request(request, OandaFinch) do
      {:ok, %Finch.Response{status: status, body: body}} when status in 200..299 ->
        {:ok, Jason.decode!(body)}
      {:ok, %Finch.Response{status: status, body: body}} ->
        {:error, "HTTP Error #{status}: #{body}"}
      {:error, reason} ->
        {:error, "Request failed: #{inspect(reason)}"}
    end
  end
end

# Main execution
api_key = System.get_env("OANDA_API_KEY") || IO.gets("Enter your OANDA API key: ") |> String.trim()

# Get accounts
case OandaClient.get_accounts(api_key) do
  {:ok, accounts_response} ->
    accounts = accounts_response["accounts"]
    IO.puts("\nAvailable accounts:")
    Enum.each(accounts, fn account -> 
      IO.puts("ID: #{account["id"]}, Name: #{account["alias"] || "N/A"}")
    end)
    
    # Select the first account for demonstration
    account_id = List.first(accounts)["id"]
    IO.puts("\nUsing account ID: #{account_id}")
    
    # Get account details
    {:ok, account_details} = OandaClient.get_account_details(api_key, account_id)
    balance = account_details["account"]["balance"]
    currency = account_details["account"]["currency"]
    IO.puts("Account Balance: #{balance} #{currency}")
    
    # Get historical candles for EUR/USD
    candle_params = %{
      "count" => "10",
      "granularity" => "H1",
      "price" => "M"
    }
    
    {:ok, candles_response} = OandaClient.get_candles(api_key, "EUR_USD", candle_params)
    
    IO.puts("\nEUR/USD Historical Prices (Last 10 H1 candles):")
    Enum.each(candles_response["candles"], fn candle ->
      time = candle["time"]
      close = candle["mid"]["c"]
      IO.puts("Time: #{time}, Close: #{close}")
    end)
    
    # Create a market order
    IO.puts("\nDo you want to place a market order for 100 units of EUR/USD? (yes/no)")
    response = IO.gets("") |> String.trim() |> String.downcase()
    
    if response == "yes" do
      order_data = %{
        "order" => %{
          "units" => "100",
          "instrument" => "EUR_USD",
          "timeInForce" => "FOK",
          "type" => "MARKET",
          "positionFill" => "DEFAULT"
        }
      }
      
      case OandaClient.create_order(api_key, account_id, order_data) do
        {:ok, order_response} ->
          IO.puts("Order created successfully!")
          IO.inspect(order_response, label: "Order Response")
        {:error, reason} ->
          IO.puts("Failed to create order: #{inspect(reason)}")
      end
    else
      IO.puts("Order placement skipped.")
    end
    
  {:error, reason} ->
    IO.puts("Failed to retrieve accounts: #{inspect(reason)}")
end
