const express = require('express');
const cors = require('cors');
const axios = require('axios');

const app = express();
const PORT = process.env.PORT || 8080;
const ENVIRONMENT = process.env.ENVIRONMENT || 'development';
const BEDROCK_MODEL_ARN = process.env.BEDROCK_MODEL_ARN || 'not-configured';

// Middleware
app.use(cors());
app.use(express.json());

// Logging middleware
app.use((req, res, next) => {
    console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
    next();
});

// Health check endpoint
app.get('/api/health', (req, res) => {
    res.status(200).json({
        status: 'healthy',
        service: 'condé-nast-backend',
        environment: ENVIRONMENT,
        timestamp: new Date().toISOString(),
        bedrock_configured: BEDROCK_MODEL_ARN !== 'not-configured'
    });
});

// API info endpoint
app.get('/api/info', (req, res) => {
    res.status(200).json({
        name: 'Condé Nast Backend API',
        version: '1.0.0',
        environment: ENVIRONMENT,
        uptime: process.uptime(),
        timestamp: new Date().toISOString(),
        endpoints: [
            'GET /api/health - Health check',
            'GET /api/info - API info',
            'POST /api/bedrock/invoke - Invoke Bedrock model',
            'GET /api/documentdb/status - DocumentDB status'
        ]
    });
});

// Bedrock invoke endpoint (placeholder)
app.post('/api/bedrock/invoke', (req, res) => {
    const { prompt } = req.body;

    if (!prompt) {
        return res.status(400).json({
            error: 'Missing prompt field in request body'
        });
    }

    if (BEDROCK_MODEL_ARN === 'not-configured') {
        return res.status(503).json({
            error: 'Bedrock model not configured',
            message: 'Set BEDROCK_MODEL_ARN environment variable'
        });
    }

    // In production, this would call AWS Bedrock SDK
    res.status(200).json({
        prompt: prompt,
        response: `[Mock Response] Bedrock model (${BEDROCK_MODEL_ARN}) would process: "${prompt}"`,
        model: BEDROCK_MODEL_ARN,
        timestamp: new Date().toISOString()
    });
});

// DocumentDB status endpoint (placeholder)
app.get('/api/documentdb/status', (req, res) => {
    const docdbEndpoint = process.env.DOCUMENTDB_ENDPOINT || 'not-configured';
    
    res.status(200).json({
        service: 'DocumentDB',
        status: docdbEndpoint === 'not-configured' ? 'not-configured' : 'connected',
        endpoint: docdbEndpoint,
        timestamp: new Date().toISOString()
    });
});

// Error handling middleware
app.use((err, req, res, next) => {
    console.error('Error:', err);
    res.status(500).json({
        error: 'Internal Server Error',
        message: err.message,
        timestamp: new Date().toISOString()
    });
});

// 404 handler
app.use((req, res) => {
    res.status(404).json({
        error: 'Not Found',
        path: req.path,
        timestamp: new Date().toISOString()
    });
});

// Start server
app.listen(PORT, () => {
    console.log(`✅ Backend API running on port ${PORT}`);
    console.log(`📍 Environment: ${ENVIRONMENT}`);
    console.log(`🧠 Bedrock Model: ${BEDROCK_MODEL_ARN}`);
    console.log(`🚀 Ready to accept requests`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('SIGTERM received. Shutting down gracefully...');
    process.exit(0);
});
