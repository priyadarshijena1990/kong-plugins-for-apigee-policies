-- handler.lua for xsltransform plugin
local pl_path = require("pl.path") -- Required for path manipulation, might need to be installed
                                  -- If not available, we can use string manipulation or kong.db.dao.plugins.get_plugin_path

local PLUGIN_NAME = "xsltransform"

-- Helper function to get the absolute path to the XSLT stylesheet
local function get_stylesheet_path(conf)
    -- In Kong, stylesheet_resource is a path relative to the plugin's root,
    -- e.g., "xsl/My-Transformation.xsl"
    -- We need to construct the full path within the Kong filesystem.
    -- Kong's plugins are typically installed in /usr/local/share/lua/5.1/kong/plugins/<plugin_name>/
    -- or similar. However, for a custom plugin, it's safer to resolve relative to the current plugin's directory.
    
    local plugin_root_path = kong.get_plugin_dir(PLUGIN_NAME)
    if not plugin_root_path then
        kong.log.err("Could not determine plugin directory using kong.get_plugin_dir. " ..
                      "This might indicate an issue with plugin loading or an older Kong version.")
        return nil, "Could not determine plugin directory"
    end
    
    local stylesheet_rel_path = conf.stylesheet_resource
    -- Remove Apigee's "xsl://" prefix if present
    if string.sub(stylesheet_rel_path, 1, 6) == "xsl://" then
        stylesheet_rel_path = string.sub(stylesheet_rel_path, 7)
    end
    
    -- Ensure stylesheet_rel_path does not contain '..' for security
    stylesheet_rel_path = stylesheet_rel_path:gsub("..", "")

    -- Use standard Lua string manipulation for path.join if pl.path is not reliable.
    -- For now, relying on pl.path, will adjust if tests fail.
    local full_path = pl_path.join(plugin_root_path, stylesheet_rel_path)
    
    -- Check if file exists
    local file_handle = io.open(full_path, "r")
    if not file_handle then
        kong.log.err("XSLT Stylesheet not found at: ", full_path)
        return nil, "XSLT Stylesheet not found"
    end
    file_handle:close()

    return full_path
end

-- Helper function to construct xsltproc command with parameters
local function build_xsltproc_command(stylesheet_path, parameters)
    local cmd_parts = {"xsltproc"}
    
    -- Add parameters
    for _, param in ipairs(parameters or {}) do
        local param_value = ""
        if param.value then
            param_value = param.value
        elseif param.ref then
            -- Attempt to get value from Kong context or request/response
            if param.ref == "request.body" then -- Special case for body content
                param_value = kong.request.get_raw_body() or ""
            elseif param.ref == "response.body" then -- Special case for body content
                param_value = kong.response.get_raw_body() or ""
            else
                -- Try to get from Kong context first (e.g., kong.ctx.shared)
                param_value = kong.ctx.shared[param.ref]
                if param_value == nil then
                    -- Fallback to other common Kong variables (headers, query args etc.)
                    param_value = kong.request.get_header(param.ref) or kong.request.get_query_arg(param.ref) or ""
                end
            end
        end
        -- Escape single quotes in parameter value to prevent command injection
        local escaped_param_value = param_value:gsub("'", "'\\''")
        table.insert(cmd_parts, "--stringparam")
        table.insert(cmd_parts, param.name)
        table.insert(cmd_parts, "'" .. escaped_param_value .. "'")
    end
    
    table.insert(cmd_parts, stylesheet_path)
    table.insert(cmd_parts, "-") -- '-' means read XML from stdin

    return table.concat(cmd_parts, " ")
end

-- Helper function to execute xsltproc and capture output
local function execute_xsltproc(xml_input, xslt_command)
    -- Using io.popen with "w+" mode to write to stdin and read from stdout/stderr
    local handle, err = io.popen(xslt_command, "w+")
    if not handle then
        kong.log.err("Failed to execute xsltproc (io.popen failed): ", err)
        return nil, "Failed to execute XSLT processor"
    end
    
    -- Write XML input to xsltproc's stdin
    handle:write(xml_input)
    handle:close("write") -- Close the write end of the pipe, signalling EOF to xsltproc
    
    local transformed_output = handle:read("*a") -- Read all output from xsltproc's stdout/stderr
    local exit_code = handle:close() -- Get return code
    
    -- In Lua, io.popen returns nil and a message on error, or true on success for close()
    -- It also returns the exit code if the command failed.
    -- We need to check the exact behavior on OpenResty/Kong.
    -- For now, assume if transformed_output is empty and exit_code is non-zero, it's an error.
    
    if exit_code ~= 0 then -- This check depends on the exact return value of handle:close() for non-zero exit codes
        kong.log.err("xsltproc command failed with exit code: ", exit_code)
        kong.log.err("XSLT Command: ", xslt_command)
        kong.log.err("XML Input (truncated): ", xml_input:sub(1, 200)) -- Log a truncated input
        kong.log.err("xsltproc Output (errors/stderr): ", transformed_output) -- xsltproc writes errors to stdout/stderr which we capture here
        return nil, "XSLT transformation failed"
    end
    
    return transformed_output
end


local XSLTransformHandler = {
  VERSION = "0.1.0",
  PRIORITY = 1000,
  schema = true, -- Indicates that this plugin has a schema.lua
}

-- The plugin will operate in both access and response phases
-- and decide based on the 'source_variable' config.
function XSLTransformHandler:new()
    return {
        access = self.access,
        response = self.response,
    }
end

function XSLTransformHandler:access(conf)
    if conf.source_variable == "request" then
        local stylesheet_path, err = get_stylesheet_path(conf)
        if not stylesheet_path then
            return kong.log.err(err)
        end
        
        local request_body = kong.request.get_raw_body()
        if not request_body then
            kong.log.warn("No request body found for XSLT transformation. Skipping.")
            return
        end
        
        if request_body == "" then
            kong.log.warn("Request body is empty for XSLT transformation. Skipping.")
            return
        end

        local xslt_command = build_xsltproc_command(stylesheet_path, conf.parameters)
        
        local transformed_body, err = execute_xsltproc(request_body, xslt_command)
        if not transformed_body then
            return kong.log.err(err)
        end
        
        if conf.output_variable == "request" then
            kong.request.set_raw_body(transformed_body)
        else
            kong.ctx.shared[conf.output_variable] = transformed_body
        end
    end
end

function XSLTransformHandler:response(conf)
    if conf.source_variable == "response" then
        local stylesheet_path, err = get_stylesheet_path(conf)
        if not stylesheet_path then
            return kong.log.err(err)
        end
        
        local response_body = kong.response.get_raw_body()
        if not response_body then
            kong.log.warn("No response body found for XSLT transformation. Skipping.")
            return
        end

        if response_body == "" then
            kong.log.warn("Response body is empty for XSLT transformation. Skipping.")
            return
        end

        local xslt_command = build_xsltproc_command(stylesheet_path, conf.parameters)
        
        local transformed_body, err = execute_xsltproc(response_body, xslt_command)
        if not transformed_body then
            return kong.log.err(err)
        end
        
        if conf.output_variable == "response" then
            kong.response.set_raw_body(transformed_body)
        else
            kong.ctx.shared[conf.output_variable] = transformed_body
        end
    end
end

return XSLTransformHandler