let wssInstance = null;

function initializeWebSocketManager(wss) {
  if (!wssInstance) {
    wssInstance = wss;
    console.log('WebSocketManager initialized.');
  }
}

function getSocketServerInstance() {
  if (!wssInstance) {
    // This might happen if accessed before server.js initializes it.
    // Depending on application structure, you might throw an error,
    // or handle it gracefully. For now, logging a warning.
    console.warn('WebSocketManager: Instance requested before initialization.');
  }
  return wssInstance;
}

module.exports = {
  initializeWebSocketManager,
  getSocketServerInstance,
};
