# Thesauros Monitoring Dashboard

Simple HTML/CSS/JavaScript monitoring dashboard for Thesauros DeFi strategy.

## Features

- **Real-time Data**: Live vault and provider information
- **APY Monitoring**: Current APY rates for all tokens
- **Network Status**: Blockchain network information
- **Event Tracking**: Recent contract events
- **Mobile Responsive**: Works on all devices
- **No Framework**: Pure HTML/CSS/JavaScript

## Quick Start

### 1. Install Dependencies
```bash
npm install
```

### 2. Start Development Server
```bash
npm run dev
```

### 3. Open Dashboard
```
http://localhost:3001
```

## Project Structure

```
monitoring-ui/
├── server.js              # Express server with API endpoints
├── simple-dashboard.html  # Complete dashboard (HTML/CSS/JS)
├── package.json           # Dependencies and scripts
├── README.md             # This file
└── node_modules/         # Dependencies
```

## API Endpoints

- `GET /api/health` - Server health check
- `GET /api/vaults` - Vault information
- `GET /api/providers` - Provider data
- `GET /api/apy` - APY rates
- `GET /api/events` - Recent events
- `GET /api/dashboard` - All data combined

## Commands

- `npm start` - Start production server
- `npm run dev` - Start development server with auto-reload

## Configuration

The dashboard automatically loads configuration from:
```
../deployments/arbitrumOne/deployed-vaults.json
```

## Troubleshooting

### Port Already in Use
```bash
# Kill process on port 3001
lsof -ti:3001 | xargs kill -9
```

### Configuration Not Found
Ensure the deployment configuration file exists and is valid JSON.

### API Errors
Check the browser console and server logs for detailed error messages.

## Comparison with React Version

This simple version:
-  No build process required
-  Faster startup
-  Smaller bundle size
-  Easier to modify
-  Less interactive features
-  No real-time updates

## License

MIT License - see LICENSE file for details.
