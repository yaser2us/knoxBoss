import express from "express";

import { McpServer, ResourceTemplate } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import { SSEServerTransport } from "@modelcontextprotocol/sdk/server/sse.js";

import { z } from "zod";

// Create an MCP server
const server = new McpServer({
    name: "demo-server",
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

// Add a dynamic greeting resource
server.registerResource(
    "greeting",
    new ResourceTemplate("greeting://{name}", { list: undefined }),
    {
        title: "Greeting Resource",      // Display name for UI
        description: "Dynamic greeting generator"
    },
    async (uri, { name }) => ({
        contents: [{
            uri: uri.href,
            text: `Hello, ${name}!`
        }]
    })
);

// Start receiving messages on stdin and sending messages on stdout
// const transport = new StdioServerTransport();
// const transport = new SSEServerTransport();

// server.connect(transport).then(r => {
//     console.log("Server started successfully", r);
// });

const app = express();
app.use(express.json());

// Store transports for each session type
const transports = {
    streamable: {},
    sse: {}
};

// Modern Streamable HTTP endpoint
app.all('/mcp', async (req, res) => {
    // Handle Streamable HTTP transport for modern clients
    // Implementation as shown in the "With Session Management" example
    // ...
});

// Legacy SSE endpoint for older clients
app.get('/sse', async (req, res) => {
    // Create SSE transport for legacy clients
    const transport = new SSEServerTransport('/messages', res);
    transports.sse[transport.sessionId] = transport;

    res.on("close", () => {
        delete transports.sse[transport.sessionId];
    });

    await server.connect(transport);
});

// Legacy message endpoint for older clients
app.post('/messages', async (req, res) => {
    const sessionId = req.query.sessionId;
    const transport = transports.sse[sessionId];
    if (transport) {
        await transport.handlePostMessage(req, res, req.body);
    } else {
        res.status(400).send('No transport found for sessionId');
    }
});

console.log(process.env.MCP_TRANSPORT, '[MCP_TRANSPORT]')

// For Claude Desktop (stdio transport)
if (process.env.MCP_TRANSPORT === 'stdio') {
    const transport = new StdioServerTransport();
    server.connect(transport).then(() => {
        // Remove this line - it's causing the JSON parsing error
        // console.error("MCP Server started with stdio transport");
    }).catch(console.error);
} else {
    // Keep your existing Express server for other clients
    // const app = express();
    // app.use(express.json());

    // ... rest of your Express code ...

    app.listen(3333, () => {
        console.log("HTTP/SSE server running on port 3333");
    });
}

// app.listen(3333);