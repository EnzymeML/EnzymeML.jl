"""
Suite.jl

This module provides the EnzymeMLSuite client for interacting with the EnzymeML graphical user interface service.
It enables retrieving and updating EnzymeML documents through HTTP requests.
"""
module Suite

using HTTP
using JSON3
using ..EnzymemlV2: EnzymeMLDocument

export EnzymeMLSuite

"""
    EnzymeMLSuite

A suite for interacting with the EnzymeML service.

# Fields
- `base_url::String`: The base URL for the EnzymeML service.

# Example
```julia
# Create a suite with default URL
suite = EnzymeMLSuite()

# Create a suite with custom URL
suite = EnzymeMLSuite("http://localhost:8080")

# Get current document
doc = suite.get_current()

# Update document
suite.update_current(doc)
```
"""
mutable struct EnzymeMLSuite
    base_url::String

    function EnzymeMLSuite(url::String="http://localhost:13452")
        new(url)
    end
end

"""
    get_current(suite::EnzymeMLSuite) -> EnzymeMLDocument

Retrieves the current EnzymeML document from the service.

# Returns
- `EnzymeMLDocument`: The current EnzymeML document.

# Throws
- `ConnectionError`: If unable to connect to the EnzymeML suite.
- `HTTP.StatusError`: If the request to the service fails.

# Example
```julia
suite = EnzymeMLSuite()
doc = suite.get_current()
```
"""
function get_current(suite::EnzymeMLSuite)::EnzymeMLDocument
    try
        response = HTTP.get("$(suite.base_url)/docs/:current")

        # Check if request was successful
        if response.status != 200
            throw(HTTP.StatusError(response.status, response))
        end

        # Parse the JSON response
        json_data = JSON3.read(response.body)
        content = json_data.data.content

        # Parse content into EnzymeMLDocument
        return JSON3.read(JSON3.write(content), EnzymeMLDocument)

    catch e
        if isa(e, HTTP.ConnectError)
            error("Could not connect to the EnzymeML suite. Make sure it is running.")
        else
            rethrow(e)
        end
    end
end

"""
    update_current(suite::EnzymeMLSuite, doc::EnzymeMLDocument)

Updates the current EnzymeML document on the service.

# Arguments
- `doc::EnzymeMLDocument`: The EnzymeML document to update.

# Throws
- `ConnectionError`: If unable to connect to the EnzymeML suite.
- `HTTP.StatusError`: If the request to the service fails.

# Example
```julia
suite = EnzymeMLSuite()
suite.update_current(doc)
```
"""
function update_current(suite::EnzymeMLSuite, doc::EnzymeMLDocument)
    try
        # Serialize the document to JSON
        json_data = JSON3.write(doc)

        # Make PUT request
        response = HTTP.put(
            "$(suite.base_url)/docs/:current",
            ["Content-Type" => "application/json"],
            body=json_data
        )

        # Check if request was successful
        if response.status != 200
            throw(HTTP.StatusError(response.status, response))
        end

        # Print success message (Julia equivalent of rich.print)
        printstyled("Document updated successfully!", bold=true, color=:green)
        println()

    catch e
        if isa(e, HTTP.ConnectError)
            error("Could not connect to the EnzymeML suite. Make sure it is running.")
        else
            rethrow(e)
        end
    end
end

# Enable method-style calling with dot syntax
Base.getproperty(suite::EnzymeMLSuite, sym::Symbol) =
    if sym === :get_current
        () -> get_current(suite)
    elseif sym === :update_current
        (doc) -> update_current(suite, doc)
    else
        getfield(suite, sym)
    end

end # module Suite
