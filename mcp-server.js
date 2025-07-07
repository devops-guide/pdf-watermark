#!/usr/bin/env node
const { McpServer } = require('@modelcontextprotocol/sdk/server/mcp.js');
const { StdioServerTransport } = require('@modelcontextprotocol/sdk/server/stdio.js');
const { z } = require('zod');
const path = require('path');

const { addWatermark } = require('./main');

// Create an MCP server
const server = new McpServer({
  name: 'pdf-watermark-server',
  version: '1.0.0',
});

server.registerTool('pdf',
  {
    title: 'pdf watermark',
    description: 'pdf add watermark, input filepath and text, return output filepath',
    inputSchema: {
      filepath: z.string().describe('input filepath'),
      text: z.string().describe('watermark text'),
    },
  },
  async ({ filepath, text }) => {
    const dir = path.dirname(filepath);
    const ext = path.extname(filepath);
    const base = path.basename(filepath, ext);
    const output = path.join(dir, `${base}-watermark${ext}`);
    await addWatermark(filepath, output, {
      textSize: 150,
      rotate: 0,
      style: 'centered',
      text,
    });
    return {
      content: [{ type: 'text', text: output }],
    };
  },
);

// Start receiving messages on stdin and sending messages on stdout
const transport = new StdioServerTransport();
server.connect(transport);
