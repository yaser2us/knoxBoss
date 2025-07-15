import express from "express";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { SSEServerTransport } from "@modelcontextprotocol/sdk/server/sse.js";
import { z } from "zod";

// Create an MCP server
const server = new McpServer({
    name: "knoxBoss",
    version: "1.0.0"
});

// Add an addition tool
server.registerTool("add",
    {
        title: "Addition Tool",
        description: "Add two numbers",
        inputSchema: { a: z.number(), b: z.number() }
    },
    async ({ a, b }) => ({
        content: [{ type: "text", text: String(a + b) }]
    })
);

// Add a multiplication tool
server.registerTool("multiply",
    {
        title: "Multiplication Tool",
        description: "Multiply two numbers",
        inputSchema: { a: z.number(), b: z.number() }
    },
    async ({ a, b }) => ({
        content: [{ type: "text", text: String(a * b) }]
    })
);

// Add a calculator tool with multiple operations
server.registerTool("calculate",
    {
        title: "Calculator Tool",
        description: "Perform basic calculations (add, subtract, multiply, divide)",
        inputSchema: {
            operation: z.enum(["add", "subtract", "multiply", "divide"]),
            a: z.number(),
            b: z.number()
        }
    },
    async ({ operation, a, b }) => {
        let result;
        switch (operation) {
            case "add":
                result = a + b;
                break;
            case "subtract":
                result = a - b;
                break;
            case "multiply":
                result = a * b;
                break;
            case "divide":
                if (b === 0) {
                    return { content: [{ type: "text", text: "Error: Division by zero" }] };
                }
                result = a / b;
                break;
            default:
                return { content: [{ type: "text", text: "Error: Invalid operation" }] };
        }
        return { content: [{ type: "text", text: `${a} ${operation} ${b} = ${result}` }] };
    }
);

// Fix the greeting resource - use simpler resource registration
server.registerResource(
    "greeting",
    "greeting://hello",
    {
        title: "Greeting Resource",
        description: "A simple greeting message",
        mimeType: "text/plain"
    },
    async () => ({
        contents: [{
            uri: "greeting://hello",
            mimeType: "text/plain",
            text: "Hello from knoxBoss MCP Server! 👋"
        }]
    })
);

// Add a dynamic greeting resource that can take parameters
server.registerResource(
    "personal-greeting",
    "greeting://personal/{name}",
    {
        title: "Personal Greeting",
        description: "Generate a personalized greeting",
        mimeType: "text/plain"
    },
    async (uri) => {
        // Extract name from URI
        const urlParts = uri.split('/');
        const name = urlParts[urlParts.length - 1] || 'Friend';

        return {
            contents: [{
                uri: uri,
                mimeType: "text/plain",
                text: `Hello, ${decodeURIComponent(name)}! Welcome to knoxBoss! 🎉`
            }]
        };
    }
);

// Add a system info resource
server.registerResource(
    "system-info",
    "system://info",
    {
        title: "System Information",
        description: "Get system information",
        mimeType: "application/json"
    },
    async () => ({
        contents: [{
            uri: "system://info",
            mimeType: "application/json",
            text: JSON.stringify({
                serverName: "knoxBoss",
                version: "1.0.0",
                timestamp: new Date().toISOString(),
                nodeVersion: process.version,
                platform: process.platform
            }, null, 2)
        }]
    })
);

// Greeting as a tool
server.registerTool("get_greeting", {
    title: "Get Greeting",
    description: "Get a greeting message",
    inputSchema: { name: z.string().optional() }
}, async ({ name = "Friend" }) => ({
    content: [{ type: "text", text: `Hello, ${name}! Welcome to knoxBoss! 👋` }]
}));

// System info as a tool
server.registerTool("get_system_info", {
    title: "Get System Info",
    description: "Get system information",
    inputSchema: {}
}, async () => ({
    content: [{
        type: "text", text: JSON.stringify({
            serverName: "knoxBoss",
            version: "1.0.0",
            timestamp: new Date().toISOString(),
            nodeVersion: process.version,
            platform: process.platform
        }, null, 2)
    }]
}));


// =============================================================================
// DEBUG: Add logging to see what's happening
// =============================================================================

// Add some debug info (only in non-stdio mode)
if (process.env.MCP_TRANSPORT !== 'stdio') {
    console.log("Registered tools:", Object.keys(server._registeredResources));
}


// Check if running in stdio mode (for Claude Desktop)
if (process.env.MCP_TRANSPORT === 'stdio' || process.argv.includes('--stdio')) {
    const transport = new StdioServerTransport();
    server.connect(transport).then(() => {
        // Don't log to console.error in stdio mode as it interferes with JSON-RPC
    }).catch((error) => {
        // Only log errors to stderr, not success messages
        process.stderr.write(`Error: ${error.message}\n`);
    });
} else {
    // HTTP/SSE server mode
    const app = express();
    app.use(express.json());

    const transports = {
        streamable: {},
        sse: {}
    };

    app.get('/sse', async (req, res) => {
        const transport = new SSEServerTransport('/messages', res);
        transports.sse[transport.sessionId] = transport;

        res.on("close", () => {
            delete transports.sse[transport.sessionId];
        });

        await server.connect(transport);
    });

    app.post('/messages', async (req, res) => {
        const sessionId = req.query.sessionId;
        const transport = transports.sse[sessionId];
        if (transport) {
            await transport.handlePostMessage(req, res, req.body);
        } else {
            res.status(400).send('No transport found for sessionId');
        }
    });

    // app.listen(3333, () => {
    //     console.log("HTTP/SSE server running on port 3333");
    // });

    app.listen(3333);
}