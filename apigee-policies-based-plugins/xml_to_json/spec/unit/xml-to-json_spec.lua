local helpers = require "spec.helpers"
local xml = require "lua-xml"
local cjson = require "cjson"
local JSON = cjson -- Use cjson for JSON operations

describe("XML to JSON Plugin", function()
  local client

  setup(function()
    client = helpers.get_client()
  end)

  teardown(function()
    if client then
      client:close()
    end
  end)

  describe("plugin: xml-to-json (request phase)", function()
    local service, route, proxy

    before_each(function()
      -- Create a service that echoes back the request body and headers
      service = assert(client:send {
        method = "POST",
        path = "/services",
        body = {
          name = "echo-request-body",
          url = "http://mockbin.org/request", -- mockbin echoes request data
        },
        headers = {
          ["Content-Type"] = "application/json"
        }
      })
      assert.res_status(201, service)
      service = cjson.decode(service.body)

      -- Create a route for the service
      route = assert(client:send {
        method = "POST",
        path = "/routes",
        body = {
          paths = { "/xml-request" },
          service = { id = service.id },
        },
        headers = {
          ["Content-Type"] = "application/json"
        }
      })
      assert.res_status(201, route)
      route = cjson.decode(route.body)

      -- Add the plugin to the route, configured for request transformation
      proxy = assert(client:send {
        method = "POST",
        path = string.format("/routes/%s/plugins", route.id),
        body = {
          name = "xml-to-json",
          config = {
            source = "request",
            strip_namespaces = true,
            attribute_prefix = "@",
            text_node_name = "#text",
          },
        },
        headers = {
          ["Content-Type"] = "application/json"
        }
      })
      assert.res_status(201, proxy)
    end)

    after_each(function()
      if service then
        assert(client:send {
          method = "DELETE",
          path = string.format("/services/%s", service.id),
        })
      end
    end)

    it("should convert XML request body to JSON", function()
      local xml_input = [[ 
        <?xml version="1.0" encoding="UTF-8"?>
        <root>
          <item id="1">
            <name>Test Item</name>
            <value type="numeric">123</value>
          </item>
          <list>
            <entry>A</entry>
            <entry>B</entry>
          </list>
        </root>
      ]]
      local expected_json_output_partial = {
        root = {
          item = {
            ["@id"] = "1",
            name = "Test Item",
            value = {
              ["@type"] = "numeric",
              ["#text"] = "123"
            }
          },
          list = {
            entry = { "A", "B" } -- Note: lua-xml often parses multiple same-named children into an array implicitly
          }
        }
      }

      local res = client:send {
        method = "POST",
        path = "/xml-request",
        headers = {
          ["Content-Type"] = "application/xml",
        },
        body = xml_input
      }

      assert.res_status(200, res)
      assert.equal("application/json", res.headers["Content-Type"]:lower())

      local body = cjson.decode(res.body)
      -- mockbin wraps the request body in a "data" field
      assert.equal(expected_json_output_partial.root.item.name, body.data.root.item.name)
      assert.equal(expected_json_output_partial.root.item.value["#text"], body.data.root.item.value["#text"])
      assert.equal(expected_json_output_partial.root.item.value["@type"], body.data.root.item.value["@type"])
      assert.same({ "A", "B" }, body.data.root.list.entry)
    end)

    it("should handle namespaces correctly (strip namespaces = true)", function()
      local xml_input = [[ 
        <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
          <soap:Body>
            <m:GetStockPrice xmlns:m="http://www.example.com/stock">
              <m:TickerSymbol>GOOG</m:TickerSymbol>
            </m:GetStockPrice>
          </soap:Body>
        </soap:Envelope>
      ]]
      local expected_json_output_partial = {
        Envelope = {
          Body = {
            GetStockPrice = {
              TickerSymbol = "GOOG"
            }
          }
        }
      }

      local res = client:send {
        method = "POST",
        path = "/xml-request",
        headers = {
          ["Content-Type"] = "application/xml",
        },
        body = xml_input
      }

      assert.res_status(200, res)
      local body = cjson.decode(res.body)
      assert.is_string(body.data.Envelope.Body.GetStockPrice.TickerSymbol)
      assert.equal(expected_json_output_partial.Envelope.Body.GetStockPrice.TickerSymbol, body.data.Envelope.Body.GetStockPrice.TickerSymbol)
    end)

  end)

  describe("plugin: xml-to-json (response phase)", function()
    local service, route, proxy

    before_each(function()
      -- Create a service that provides an XML response
      service = assert(client:send {
        method = "POST",
        path = "/services",
        body = {
          name = "xml-response-service",
          url = "http://mockbin.org/bin/e2264c78-6874-4b5b-8086-66440b8f0547", -- A mockbin endpoint returning XML
        },
        headers = {
          ["Content-Type"] = "application/json"
        }
      })
      assert.res_status(201, service)
      service = cjson.decode(service.body)

      -- Create a route for the service
      route = assert(client:send {
        method = "POST",
        path = "/routes",
        body = {
          paths = { "/xml-response" },
          service = { id = service.id },
        },
        headers = {
          ["Content-Type"] = "application/json"
        }
      })
      assert.res_status(201, route)
      route = cjson.decode(route.body)

      -- Add the plugin to the route, configured for response transformation
      proxy = assert(client:send {
        method = "POST",
        path = string.format("/routes/%s/plugins", route.id),
        body = {
          name = "xml-to-json",
          config = {
            source = "response",
            strip_namespaces = true,
            attribute_prefix = "@",
            text_node_name = "#text",
          },
        },
        headers = {
          ["Content-Type"] = "application/json"
        }
      })
      assert.res_status(201, proxy)
    end)

    after_each(function()
      if service then
        assert(client:send {
          method = "DELETE",
          path = string.format("/services/%s", service.id),
        })
      end
    end)

    it("should convert XML response body to JSON", function()
      local res = client:send {
        method = "GET",
        path = "/xml-response",
        headers = {
          ["Accept"] = "application/xml", -- Request XML from mockbin
        },
      }

      assert.res_status(200, res)
      assert.equal("application/json", res.headers["Content-Type"]:lower())

      local body = cjson.decode(res.body)
      assert.is_table(body)
      assert.equal("Apigee Policy XML example", body.root.name)
      assert.equal("Some value", body.root.data["#text"])
      assert.equal("attr_value", body.root.data["@attr"])
    end)

    it("should handle arrays_key_ending correctly", function()
      -- Configure plugin for array handling
      assert(client:send {
        method = "PATCH",
        path = string.format("/routes/%s/plugins/%s", route.id, proxy.id),
        body = {
          config = {
            source = "response",
            strip_namespaces = true,
            attribute_prefix = "@",
            text_node_name = "#text",
            arrays_key_ending = "_list",
            arrays_key_ending_strip = true,
          },
        },
        headers = {
          ["Content-Type"] = "application/json"
        }
      })
      assert.res_status(200, res)

      local res = client:send {
        method = "GET",
        path = "/xml-response",
        headers = {
          ["Accept"] = "application/xml", -- Request XML from mockbin
        },
      }

      assert.res_status(200, res)
      assert.equal("application/json", res.headers["Content-Type"]:lower())

      local body = cjson.decode(res.body)
      assert.is_table(body)
      -- This test relies on mockbin returning XML with elements like <item_list> 
      -- Mockbin for XML content:
      -- {
      --  "status": 200,
      --  "headers": {
      --    "Content-Type": "application/xml"
      --  },
      --  "body": "<?xml version=\"1.0\" encoding=\"UTF-8\"?><root><name>Apigee Policy XML example</name><data attr=\"attr_value\">Some value</data><item_list><item>1</item><item>2</item></item_list></root>"
      -- }
      -- Update mockbin URL to one that includes item_list
      service = assert(client:send {
        method = "PATCH",
        path = string.format("/services/%s", service.id),
        body = {
          url = "http://mockbin.org/bin/21d5c210-9018-4e8c-8f92-5645a277742d", -- Another mockbin endpoint with item_list
        },
        headers = {
          ["Content-Type"] = "application/json"
        }
      })
      assert.res_status(200, service)

      res = client:send {
        method = "GET",
        path = "/xml-response",
        headers = {
          ["Accept"] = "application/xml", -- Request XML from mockbin
        },
      }

      assert.res_status(200, res)
      assert.equal("application/json", res.headers["Content-Type"]:lower())
      body = cjson.decode(res.body)

      assert.is_table(body.root.item) -- Should be an array now
      assert.same({ "1", "2" }, body.root.item)
    end)

  end)

end)
