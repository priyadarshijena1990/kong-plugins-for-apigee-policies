-- test_xsltransform.lua for xsltransform plugin
local busted = require("busted")
local helpers = require("spec.helpers")

local PLUGIN_NAME = "xsltransform"

-- Helper function to create mock XSLT stylesheet content in a temporary file
local function create_temp_stylesheet(content)
  local tmp_file = os.tmpname()
  local f = io.open(tmp_file, "w")
  f:write(content)
  f:close()
  return tmp_file
end

-- Helper function to delete temporary file
local function delete_temp_file(filepath)
  os.remove(filepath)
end

describe("XSLTransform Plugin", function()
  local client
  local admin_client
  local service

  setup(function()
    helpers.start_kong()
    admin_client = helpers.admin_client()
  end)

  teardown(function()
    if client then client:close() end
    if admin_client then admin_client:close() end
    helpers.stop_kong()
  end)

  before_each(function()
    service = admin_client.services:create({
      name = "test-service",
      host = "mockbin.org",
      port = 80,
    })
    local route = admin_client.routes:create({
      paths = {"/test"},
      service = { id = service.id },
    })
    client = helpers.proxy_client()
  end)

  after_each(function()
    admin_client.services:delete(service.id)
  end)

  describe("plugin schema and configuration", function()
    it("should allow valid configuration with stylesheet_resource", function()
      local ok, err = admin_client.plugins:create({
        name = PLUGIN_NAME,
        service = { id = service.id },
        config = {
          stylesheet_resource = "xsl/test.xsl",
          source_variable = "request",
          output_variable = "transformed_request_body",
        },
      })
      assert.is_nil(err)
      assert.is_truthy(ok)
      assert.equals(ok.name, PLUGIN_NAME)
    end)

    it("should reject configuration without stylesheet_resource", function()
      local ok, err = admin_client.plugins:create({
        name = PLUGIN_NAME,
        service = { id = service.id },
        config = {
          source_variable = "request",
        },
      })
      assert.is_nil(ok)
      assert.is_truthy(err)
      assert.match("stylesheet_resource: required field missing", err)
    end)

    it("should allow parameters with 'value'", function()
      local ok, err = admin_client.plugins:create({
        name = PLUGIN_NAME,
        service = { id = service.id },
        config = {
          stylesheet_resource = "xsl/test.xsl",
          parameters = {
            { name = "param1", value = "static_value" },
          },
        },
      })
      assert.is_nil(err)
      assert.is_truthy(ok)
    end)

    it("should allow parameters with 'ref'", function()
      local ok, err = admin_client.plugins:create({
        name = PLUGIN_NAME,
        service = { id = service.id },
        config = {
          stylesheet_resource = "xsl/test.xsl",
          parameters = {
            { name = "param2", ref = "kong.request.get_header('X-Some-Header')" },
          },
        },
      })
      assert.is_nil(err)
      assert.is_truthy(ok)
    end)

    it("should reject parameters with both 'value' and 'ref'", function()
      local ok, err = admin_client.plugins:create({
        name = PLUGIN_NAME,
        service = { id = service.id },
        config = {
          stylesheet_resource = "xsl/test.xsl",
          parameters = {
            { name = "param3", value = "val", ref = "ref_val" },
          },
        },
      })
      assert.is_nil(ok)
      assert.is_truthy(err)
      assert.match("either 'value' or 'ref' must be provided, but not both", err)
    end)

    it("should reject parameters with neither 'value' nor 'ref'", function()
      local ok, err = admin_client.plugins:create({
        name = PLUGIN_NAME,
        service = { id = service.id },
        config = {
          stylesheet_resource = "xsl/test.xsl",
          parameters = {
            { name = "param4" },
          },
        },
      })
      assert.is_nil(ok)
      assert.is_truthy(err)
      assert.match("either 'value' or 'ref' must be provided, but not both", err)
    end)
  end)

  describe("XSLT Transformation Functionality", function()
    local xsl_content = [[
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="xml" indent="yes"/>
  <xsl:param name="p_header"/>
  <xsl:param name="p_static"/>
  <xsl:template match="/">
    <transformed>
      <header><xsl:value-of select="$p_header"/></header>
      <static><xsl:value-of select="$p_static"/></static>
      <original_input>
        <xsl:copy-of select="."/>
      </original_input>
    </transformed>
  </xsl:template>
</xsl:stylesheet>
    ]]
    local xml_input = [[
<?xml version="1.0" encoding="UTF-8"?>
<data><item>value</item></data>
    ]]

    local xsl_file_path

    setup(function()
      xsl_file_path = create_temp_stylesheet(xsl_content)
    end)

    teardown(function()
      delete_temp_file(xsl_file_path)
    end)

    it("should transform request body with parameters", function()
      -- Temporarily copy the XSLT to the plugin's xsl directory for testing purposes
      local plugin_xsl_dir = helpers.get_plugin_dir(PLUGIN_NAME) .. "/xsl"
      local test_xsl_path = plugin_xsl_dir .. "/test.xsl"
      os.rename(xsl_file_path, test_xsl_path) -- Move temp file into plugin's xsl directory
      
      local ok, err = admin_client.plugins:create({
        name = PLUGIN_NAME,
        service = { id = service.id },
        config = {
          stylesheet_resource = "xsl/test.xsl", -- Use the temporary stylesheet
          source_variable = "request",
          output_variable = "request", -- Overwrite request body
          parameters = {
            { name = "p_header", ref = "request.headers.x-test-header" },
            { name = "p_static", value = "HelloTransform" },
          },
        },
      })
      assert.is_nil(err)
      assert.is_truthy(ok)

      local res = client:send({
        method = "POST",
        path = "/test",
        headers = {
          ["Host"] = "mockbin.org",
          ["Content-Type"] = "application/xml",
          ["X-Test-Header"] = "MyHeaderValue",
        },
        body = xml_input,
      })

      assert.response(res).has.status(200)
      assert.response(res).has.header("Content-Type", "application/xml")

      local transformed_body = res.body
      assert.match("<header>MyHeaderValue</header>", transformed_body)
      assert.match("<static>HelloTransform</static>", transformed_body)
      assert.match("<original_input>", transformed_body)
      assert.match("<data><item>value</item></data>", transformed_body)

      -- Clean up the copied XSLT
      os.remove(test_xsl_path)
    end)

    it("should transform response body with parameters", function()
      -- Temporarily copy the XSLT to the plugin's xsl directory for testing purposes
      local plugin_xsl_dir = helpers.get_plugin_dir(PLUGIN_NAME) .. "/xsl"
      local test_xsl_path = plugin_xsl_dir .. "/test_response.xsl"
      os.rename(xsl_file_path, test_xsl_path) -- Move temp file into plugin's xsl directory

      local ok, err = admin_client.plugins:create({
        name = PLUGIN_NAME,
        service = { id = service.id },
        config = {
          stylesheet_resource = "xsl/test_response.xsl", -- Use the temporary stylesheet
          source_variable = "response",
          output_variable = "response", -- Overwrite response body
          parameters = {
            { name = "p_header", ref = "request.headers.x-request-id" }, -- Example: use a request header for response XSLT param
            { name = "p_static", value = "ResponseTransform" },
          },
        },
      })
      assert.is_nil(err)
      assert.is_truthy(ok)

      -- Mockbin will echo back the body, so we can send a simple XML
      local res = client:send({
        method = "POST",
        path = "/test",
        headers = {
          ["Host"] = "mockbin.org",
          ["Content-Type"] = "application/xml",
          ["X-Request-Id"] = "RespReqID123",
        },
        body = xml_input,
      })

      assert.response(res).has.status(200)
      assert.response(res).has.header("Content-Type", "application/xml")

      local transformed_body = res.body
      assert.match("<header>RespReqID123</header>", transformed_body)
      assert.match("<static>ResponseTransform</static>", transformed_body)
      assert.match("<original_input>", transformed_body)
      -- The original mockbin response is XML_INPUT, which is then transformed
      assert.match("<data><item>value</item></data>", transformed_body)
      
      -- Clean up the copied XSLT
      os.remove(test_xsl_path)
    end)
  end)
end)