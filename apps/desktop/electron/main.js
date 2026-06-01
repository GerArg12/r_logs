const { app, BrowserWindow, dialog } = require('electron');
const { spawn } = require('node:child_process');
const path = require('node:path');
const http = require('node:http');

const shinyPort = process.env.SHINY_PORT || '3838';
const shinyUrl = `http://127.0.0.1:${shinyPort}`;
let shinyProcess;

function waitForShiny(retries = 60) {
  return new Promise((resolve, reject) => {
    const check = remaining => {
      const request = http.get(shinyUrl, response => {
        response.resume();
        resolve();
      });

      request.on('error', error => {
        if (remaining <= 0) {
          reject(error);
          return;
        }

        setTimeout(() => check(remaining - 1), 500);
      });
    };

    check(retries);
  });
}

function startShiny() {
  const shinyPath = app.isPackaged
    ? path.join(process.resourcesPath, 'shiny')
    : path.resolve(__dirname, '../shiny');

  shinyProcess = spawn('R', [
    '-e',
    `shiny::runApp('${shinyPath}', host='127.0.0.1', port=${shinyPort}, launch.browser=FALSE)`
  ], {
    env: {
      ...process.env,
      SHINY_PORT: shinyPort
    },
    stdio: 'inherit'
  });

  shinyProcess.on('exit', code => {
    if (code !== 0 && !app.isQuiting) {
      dialog.showErrorBox('Shiny finalizo inesperadamente', `Codigo de salida: ${code}`);
    }
  });
}

async function createWindow() {
  startShiny();
  await waitForShiny();

  const mainWindow = new BrowserWindow({
    width: 1180,
    height: 780,
    minWidth: 960,
    minHeight: 620,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js')
    }
  });

  await mainWindow.loadURL(shinyUrl);
}

app.whenReady().then(createWindow).catch(error => {
  dialog.showErrorBox('No se pudo iniciar R Logs Desktop', error.message);
  app.quit();
});

app.on('before-quit', () => {
  app.isQuiting = true;
  if (shinyProcess) {
    shinyProcess.kill();
  }
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});
